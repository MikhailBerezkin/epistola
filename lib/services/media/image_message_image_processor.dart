import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../domain/models/image_message_limits.dart';
import '../avatar/avatar_image_compressor_gateway.dart';
import '../avatar/avatar_image_pipeline_config.dart';
import '../avatar/flutter_image_compress_avatar_image_compressor_gateway.dart';

enum ImageMessageImageVariant { thumbnail, full }

final class ImageMessageImageDimensions {
  const ImageMessageImageDimensions({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;

  bool get isValid => width > 0 && height > 0;

  double get aspectRatio => width / height;
}

final class ImageMessageImageProcessingException implements Exception {
  const ImageMessageImageProcessingException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() {
    return 'ImageMessageImageProcessingException($code): $message';
  }
}

final class ImageMessageImageHardLimitExceededException implements Exception {
  const ImageMessageImageHardLimitExceededException({
    required this.variant,
    required this.actualBytes,
    required this.maximumBytes,
  });

  final ImageMessageImageVariant variant;
  final int actualBytes;
  final int maximumBytes;

  @override
  String toString() {
    return 'ImageMessageImageHardLimitExceededException: '
        '${variant.name} image has $actualBytes bytes, '
        'maximum is $maximumBytes bytes.';
  }
}

typedef ImageMessageImageProbe =
    Future<ImageMessageImageDimensions> Function(String path);

typedef PreparedImageMessageCleanupInvoker =
    Future<bool> Function({
      required Directory workingDirectory,
      required Iterable<String> filePaths,
    });

final class PreparedImageMessageImages {
  PreparedImageMessageImages._({
    required this.thumbnailPath,
    required this.fullPath,
    required this.thumbnailWidth,
    required this.thumbnailHeight,
    required this.fullWidth,
    required this.fullHeight,
    required this.thumbnailSizeBytes,
    required this.fullSizeBytes,
    required this._workingDirectory,
    required this._cleanupInvoker,
  });

  final String thumbnailPath;
  final String fullPath;

  final int thumbnailWidth;
  final int thumbnailHeight;
  final int fullWidth;
  final int fullHeight;

  final int thumbnailSizeBytes;
  final int fullSizeBytes;

  final Directory _workingDirectory;
  final PreparedImageMessageCleanupInvoker _cleanupInvoker;

  Future<void>? _cleanupInFlight;
  bool _isCleaned = false;

  File get thumbnailFile => File(thumbnailPath);

  File get fullFile => File(fullPath);

  Future<void> cleanup() {
    if (_isCleaned) {
      return Future.value();
    }

    return _cleanupInFlight ??= _runCleanup();
  }

  Future<void> _runCleanup() async {
    try {
      _isCleaned = await _cleanupInvoker(
        workingDirectory: _workingDirectory,
        filePaths: [thumbnailPath, fullPath],
      );
    } catch (_) {
      // A later cleanup call may retry a transient cleanup failure.
    } finally {
      _cleanupInFlight = null;
    }
  }
}

final class ImageMessageImageProcessor {
  ImageMessageImageProcessor({
    AvatarImageCompressorGateway? compressor,
    ImageMessageImageProbe? probe,
    this._cleanupInvoker = _cleanupOwnedFiles,
  }) : _compressor =
           compressor ?? FlutterImageCompressAvatarImageCompressorGateway(),
       _probe = probe ?? _readImageDimensions;

  static const String _temporaryDirectoryPrefix = 'epistola_image_message_';

  static const List<int> _thumbnailQualityAttempts = [
    78,
    70,
    62,
    54,
    46,
    38,
    30,
  ];

  static const List<int> _fullQualityAttempts = [
    86,
    80,
    74,
    68,
    62,
    56,
    50,
    44,
    38,
    32,
  ];

  final AvatarImageCompressorGateway _compressor;
  final ImageMessageImageProbe _probe;
  final PreparedImageMessageCleanupInvoker _cleanupInvoker;

  Future<PreparedImageMessageImages> process(String sourcePath) async {
    final sourceFile = await _validateSourceFile(sourcePath);
    final sourceDimensions = await _probe(sourceFile.path);

    if (!sourceDimensions.isValid) {
      throw const ImageMessageImageProcessingException(
        code: 'invalid_source_dimensions',
        message: 'Source image dimensions are invalid.',
      );
    }

    final workingDirectory = await Directory.systemTemp.createTemp(
      _temporaryDirectoryPrefix,
    );

    _PreparedImageMessageVariant? thumbnail;
    _PreparedImageMessageVariant? full;

    try {
      thumbnail = await _compressVariant(
        variant: ImageMessageImageVariant.thumbnail,
        sourcePath: sourceFile.path,
        workingDirectory: workingDirectory,
        sourceDimensions: sourceDimensions,
        maxDimension: ImageMessageLimits.maxThumbnailDimension,
        desiredSizeBytes: ImageMessageLimits.maxThumbnailSizeBytes,
        hardMaximumSizeBytes: ImageMessageLimits.maxThumbnailSizeBytes,
        qualityAttempts: _thumbnailQualityAttempts,
      );

      full = await _compressVariant(
        variant: ImageMessageImageVariant.full,
        sourcePath: sourceFile.path,
        workingDirectory: workingDirectory,
        sourceDimensions: sourceDimensions,
        maxDimension: ImageMessageLimits.maxFullDimension,
        desiredSizeBytes: ImageMessageLimits.targetFullSizeBytes,
        hardMaximumSizeBytes: ImageMessageLimits.maxFullSizeBytes,
        qualityAttempts: _fullQualityAttempts,
      );

      _validateVariantRelationship(thumbnail: thumbnail, full: full);

      return PreparedImageMessageImages._(
        thumbnailPath: thumbnail.path,
        fullPath: full.path,
        thumbnailWidth: thumbnail.dimensions.width,
        thumbnailHeight: thumbnail.dimensions.height,
        fullWidth: full.dimensions.width,
        fullHeight: full.dimensions.height,
        thumbnailSizeBytes: thumbnail.sizeBytes,
        fullSizeBytes: full.sizeBytes,
        workingDirectory: workingDirectory,
        cleanupInvoker: _cleanupInvoker,
      );
    } catch (error, stackTrace) {
      try {
        await _cleanupInvoker(
          workingDirectory: workingDirectory,
          filePaths: [
            if (thumbnail != null) thumbnail.path,
            if (full != null) full.path,
          ],
        );
      } catch (_) {
        // Cleanup must not replace the original processing failure.
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<_PreparedImageMessageVariant> _compressVariant({
    required ImageMessageImageVariant variant,
    required String sourcePath,
    required Directory workingDirectory,
    required ImageMessageImageDimensions sourceDimensions,
    required int maxDimension,
    required int desiredSizeBytes,
    required int hardMaximumSizeBytes,
    required List<int> qualityAttempts,
  }) async {
    final requestedDimensions = _scaleDown(
      dimensions: sourceDimensions,
      maxDimension: maxDimension,
    );

    var lastOutputSizeBytes = 0;

    for (
      var attemptIndex = 0;
      attemptIndex < qualityAttempts.length;
      attemptIndex++
    ) {
      final targetPath = _childPath(
        workingDirectory,
        '${variant.name}_$attemptIndex.jpg',
      );

      final output = await _compressor.compress(
        AvatarImageCompressionRequest(
          sourcePath: sourcePath,
          targetPath: targetPath,
          format: AvatarImageFormat.jpeg,
          width: requestedDimensions.width,
          height: requestedDimensions.height,
          quality: qualityAttempts[attemptIndex],
          keepExif: false,
          autoCorrectionAngle: true,
          rotate: 0,
        ),
      );

      final outputPath = output?.path.trim() ?? '';

      if (outputPath.isEmpty) {
        throw const ImageMessageImageProcessingException(
          code: 'compression_output_missing',
          message: 'Image compressor returned no output.',
        );
      }

      if (!_samePath(outputPath, targetPath)) {
        throw const ImageMessageImageProcessingException(
          code: 'unexpected_output_path',
          message: 'Image compressor returned an unexpected output path.',
        );
      }

      final outputFile = File(outputPath);

      if (!await outputFile.exists()) {
        throw const ImageMessageImageProcessingException(
          code: 'compression_output_missing',
          message: 'Compressed image file does not exist.',
        );
      }

      final outputSizeBytes = await outputFile.length();
      lastOutputSizeBytes = outputSizeBytes;

      if (outputSizeBytes <= 0) {
        throw const ImageMessageImageProcessingException(
          code: 'compression_output_empty',
          message: 'Compressed image file is empty.',
        );
      }

      final outputDimensions = await _probe(outputPath);

      _validateOutputDimensions(
        variant: variant,
        sourceDimensions: sourceDimensions,
        outputDimensions: outputDimensions,
        maxDimension: maxDimension,
      );

      final isWithinDesiredSize = outputSizeBytes <= desiredSizeBytes;
      final isLastAttempt = attemptIndex == qualityAttempts.length - 1;
      final isWithinHardMaximum = outputSizeBytes <= hardMaximumSizeBytes;

      if (isWithinDesiredSize || (isLastAttempt && isWithinHardMaximum)) {
        return _PreparedImageMessageVariant(
          path: outputPath,
          dimensions: outputDimensions,
          sizeBytes: outputSizeBytes,
        );
      }

      await _deleteRejectedAttempt(outputPath);

      if (isLastAttempt) {
        throw ImageMessageImageHardLimitExceededException(
          variant: variant,
          actualBytes: outputSizeBytes,
          maximumBytes: hardMaximumSizeBytes,
        );
      }
    }

    throw ImageMessageImageHardLimitExceededException(
      variant: variant,
      actualBytes: lastOutputSizeBytes,
      maximumBytes: hardMaximumSizeBytes,
    );
  }

  static Future<File> _validateSourceFile(String sourcePath) async {
    final normalizedPath = sourcePath.trim();

    if (normalizedPath.isEmpty || normalizedPath != sourcePath) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'Source path must be a non-empty trimmed string.',
      );
    }

    final sourceFile = File(normalizedPath);

    if (!await sourceFile.exists()) {
      throw StateError('Source image file does not exist: $normalizedPath');
    }

    if (await sourceFile.length() <= 0) {
      throw const ImageMessageImageProcessingException(
        code: 'source_file_empty',
        message: 'Source image file is empty.',
      );
    }

    return sourceFile;
  }

  static ImageMessageImageDimensions _scaleDown({
    required ImageMessageImageDimensions dimensions,
    required int maxDimension,
  }) {
    final longestSide = math.max(dimensions.width, dimensions.height);

    if (longestSide <= maxDimension) {
      return dimensions;
    }

    final scale = maxDimension / longestSide;

    return ImageMessageImageDimensions(
      width: math.max(1, (dimensions.width * scale).round()),
      height: math.max(1, (dimensions.height * scale).round()),
    );
  }

  static void _validateOutputDimensions({
    required ImageMessageImageVariant variant,
    required ImageMessageImageDimensions sourceDimensions,
    required ImageMessageImageDimensions outputDimensions,
    required int maxDimension,
  }) {
    if (!outputDimensions.isValid) {
      throw const ImageMessageImageProcessingException(
        code: 'invalid_output_dimensions',
        message: 'Compressed image dimensions are invalid.',
      );
    }

    if (outputDimensions.width > maxDimension ||
        outputDimensions.height > maxDimension) {
      throw ImageMessageImageProcessingException(
        code: 'output_dimensions_exceeded',
        message: '${variant.name} image exceeds the $maxDimension pixel limit.',
      );
    }

    final aspectRatioDifference = _aspectRatioDifferenceAllowingRotation(
      sourceDimensions,
      outputDimensions,
    );

    if (aspectRatioDifference > ImageMessageLimits.maxAspectRatioDifference) {
      throw const ImageMessageImageProcessingException(
        code: 'aspect_ratio_changed',
        message: 'Compressed image aspect ratio changed unexpectedly.',
      );
    }
  }

  static void _validateVariantRelationship({
    required _PreparedImageMessageVariant thumbnail,
    required _PreparedImageMessageVariant full,
  }) {
    if (full.dimensions.width < thumbnail.dimensions.width ||
        full.dimensions.height < thumbnail.dimensions.height) {
      throw const ImageMessageImageProcessingException(
        code: 'variant_dimensions_invalid',
        message: 'Full image must not be smaller than its thumbnail.',
      );
    }

    final aspectRatioDifference =
        (thumbnail.dimensions.aspectRatio - full.dimensions.aspectRatio).abs();

    if (aspectRatioDifference > ImageMessageLimits.maxAspectRatioDifference) {
      throw const ImageMessageImageProcessingException(
        code: 'variant_aspect_ratio_mismatch',
        message: 'Thumbnail and full image aspect ratios do not match.',
      );
    }
  }

  static double _aspectRatioDifferenceAllowingRotation(
    ImageMessageImageDimensions first,
    ImageMessageImageDimensions second,
  ) {
    final directDifference = (first.aspectRatio - second.aspectRatio).abs();

    final rotatedDifference = ((1 / first.aspectRatio) - second.aspectRatio)
        .abs();

    return math.min(directDifference, rotatedDifference);
  }

  static Future<ImageMessageImageDimensions> _readImageDimensions(
    String path,
  ) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);

      try {
        final frame = await codec.getNextFrame();

        try {
          return ImageMessageImageDimensions(
            width: frame.image.width,
            height: frame.image.height,
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const ImageMessageImageProcessingException(
          code: 'image_dimensions_unavailable',
          message: 'Could not read image dimensions.',
        ),
        stackTrace,
      );
    }
  }

  static Future<void> _deleteRejectedAttempt(String path) async {
    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException catch (error) {
      throw ImageMessageImageProcessingException(
        code: 'temporary_file_cleanup_failed',
        message: 'Could not delete a rejected image attempt: ${error.message}',
      );
    }
  }

  static String _childPath(Directory directory, String fileName) {
    return '${directory.path}${Platform.pathSeparator}$fileName';
  }

  static bool _samePath(String first, String second) {
    final firstUri = File(first).absolute.uri.normalizePath();
    final secondUri = File(second).absolute.uri.normalizePath();

    if (Platform.isWindows) {
      return firstUri.toString().toLowerCase() ==
          secondUri.toString().toLowerCase();
    }

    return firstUri == secondUri;
  }
}

final class _PreparedImageMessageVariant {
  const _PreparedImageMessageVariant({
    required this.path,
    required this.dimensions,
    required this.sizeBytes,
  });

  final String path;
  final ImageMessageImageDimensions dimensions;
  final int sizeBytes;
}

Future<bool> _cleanupOwnedFiles({
  required Directory workingDirectory,
  required Iterable<String> filePaths,
}) async {
  for (final path in filePaths) {
    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Continue cleanup so one failed file cannot strand other outputs.
    }
  }

  try {
    if (await workingDirectory.exists()) {
      await workingDirectory.delete(recursive: true);
    }
  } catch (_) {
    // Cleanup is best-effort and remains retryable.
  }

  try {
    return !await workingDirectory.exists();
  } catch (_) {
    return false;
  }
}
