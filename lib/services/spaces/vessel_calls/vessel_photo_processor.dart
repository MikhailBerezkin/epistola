import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../avatar/avatar_image_compressor_gateway.dart';
import '../../avatar/avatar_image_pipeline_config.dart';
import '../../avatar/flutter_image_compress_avatar_image_compressor_gateway.dart';
import 'vessel_photo_pipeline_config.dart';

enum VesselPhotoVariant { thumbnail, full }

final class VesselPhotoDimensions {
  const VesselPhotoDimensions({required this.width, required this.height});

  final int width;
  final int height;

  bool get isValid => width > 0 && height > 0;

  double get aspectRatio => width / height;
}

final class VesselPhotoProcessingException implements Exception {
  const VesselPhotoProcessingException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() {
    return 'VesselPhotoProcessingException($code): $message';
  }
}

final class VesselPhotoHardLimitExceededException implements Exception {
  const VesselPhotoHardLimitExceededException({
    required this.variant,
    required this.actualBytes,
    required this.maximumBytes,
  });

  final VesselPhotoVariant variant;
  final int actualBytes;
  final int maximumBytes;

  @override
  String toString() {
    return 'VesselPhotoHardLimitExceededException: '
        '${variant.name} has $actualBytes bytes, '
        'maximum is $maximumBytes bytes.';
  }
}

typedef VesselPhotoProbe = Future<VesselPhotoDimensions> Function(String path);

typedef VesselPhotoCleanupInvoker =
    Future<bool> Function({
      required Directory workingDirectory,
      required Iterable<String> filePaths,
    });

final class PreparedVesselPhotoImages {
  PreparedVesselPhotoImages._({
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
  final VesselPhotoCleanupInvoker _cleanupInvoker;

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
        filePaths: <String>[thumbnailPath, fullPath],
      );
    } catch (_) {
      // Повторный cleanup сможет попробовать удалить файлы позже.
    } finally {
      _cleanupInFlight = null;
    }
  }
}

final class VesselPhotoProcessor {
  VesselPhotoProcessor({
    AvatarImageCompressorGateway? compressor,
    VesselPhotoProbe? probe,
    this._cleanupInvoker = _cleanupOwnedFiles,
  }) : _compressor =
           compressor ?? FlutterImageCompressAvatarImageCompressorGateway(),
       _probe = probe ?? _readImageDimensions;

  static const String _temporaryDirectoryPrefix = 'epistola_vessel_photo_';

  final AvatarImageCompressorGateway _compressor;
  final VesselPhotoProbe _probe;
  final VesselPhotoCleanupInvoker _cleanupInvoker;

  Future<PreparedVesselPhotoImages> process(String sourcePath) async {
    final sourceFile = await _validateSourceFile(sourcePath);

    final sourceDimensions = await _probe(sourceFile.path);

    if (!sourceDimensions.isValid) {
      throw const VesselPhotoProcessingException(
        code: 'invalid_source_dimensions',
        message: 'Source image dimensions are invalid.',
      );
    }

    final workingDirectory = await Directory.systemTemp.createTemp(
      _temporaryDirectoryPrefix,
    );

    _PreparedVesselPhotoVariant? thumbnail;
    _PreparedVesselPhotoVariant? full;

    try {
      thumbnail = await _compressVariant(
        variant: VesselPhotoVariant.thumbnail,
        sourcePath: sourceFile.path,
        workingDirectory: workingDirectory,
        sourceDimensions: sourceDimensions,
        config: VesselPhotoPipelineConfig.thumbnail,

        // Для thumbnail нам достаточно уложиться в hard-limit.
        desiredSizeBytes:
            VesselPhotoPipelineConfig.thumbnail.hardMaximumSizeBytes,
      );

      full = await _compressVariant(
        variant: VesselPhotoVariant.full,
        sourcePath: sourceFile.path,
        workingDirectory: workingDirectory,
        sourceDimensions: sourceDimensions,
        config: VesselPhotoPipelineConfig.full,
        desiredSizeBytes: VesselPhotoPipelineConfig.targetFullSizeBytes,
      );

      _validateVariantRelationship(thumbnail: thumbnail, full: full);

      return PreparedVesselPhotoImages._(
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
          filePaths: <String>[
            if (thumbnail != null) thumbnail.path,
            if (full != null) full.path,
          ],
        );
      } catch (_) {
        // Ошибка cleanup не должна скрывать исходную ошибку.
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<_PreparedVesselPhotoVariant> _compressVariant({
    required VesselPhotoVariant variant,
    required String sourcePath,
    required Directory workingDirectory,
    required VesselPhotoDimensions sourceDimensions,
    required VesselPhotoVariantConfig config,
    required int desiredSizeBytes,
  }) async {
    final requestedDimensions = _scaleDown(
      dimensions: sourceDimensions,
      maxDimension: config.maxDimension,
    );

    var lastOutputSizeBytes = 0;

    for (
      var attemptIndex = 0;
      attemptIndex < config.qualityAttempts.length;
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
          quality: config.qualityAttempts[attemptIndex],
          keepExif: false,
          autoCorrectionAngle: true,
          rotate: 0,
        ),
      );

      final outputPath = output?.path.trim() ?? '';

      if (outputPath.isEmpty) {
        throw const VesselPhotoProcessingException(
          code: 'compression_output_missing',
          message: 'Image compressor returned no output.',
        );
      }

      if (!_samePath(outputPath, targetPath)) {
        throw const VesselPhotoProcessingException(
          code: 'unexpected_output_path',
          message: 'Image compressor returned an unexpected output path.',
        );
      }

      final outputFile = File(outputPath);

      if (!await outputFile.exists()) {
        throw const VesselPhotoProcessingException(
          code: 'compression_output_missing',
          message: 'Compressed image file does not exist.',
        );
      }

      final outputSizeBytes = await outputFile.length();

      lastOutputSizeBytes = outputSizeBytes;

      if (outputSizeBytes <= 0) {
        throw const VesselPhotoProcessingException(
          code: 'compression_output_empty',
          message: 'Compressed image file is empty.',
        );
      }

      final outputDimensions = await _probe(outputPath);

      _validateOutputDimensions(
        sourceDimensions: sourceDimensions,
        outputDimensions: outputDimensions,
        maxDimension: config.maxDimension,
      );

      final isWithinDesiredSize = outputSizeBytes <= desiredSizeBytes;

      final isLastAttempt = attemptIndex == config.qualityAttempts.length - 1;

      final isWithinHardMaximum =
          outputSizeBytes <= config.hardMaximumSizeBytes;

      if (isWithinDesiredSize || (isLastAttempt && isWithinHardMaximum)) {
        return _PreparedVesselPhotoVariant(
          path: outputPath,
          dimensions: outputDimensions,
          sizeBytes: outputSizeBytes,
        );
      }

      await _deleteRejectedAttempt(outputPath);

      if (isLastAttempt) {
        throw VesselPhotoHardLimitExceededException(
          variant: variant,
          actualBytes: outputSizeBytes,
          maximumBytes: config.hardMaximumSizeBytes,
        );
      }
    }

    throw VesselPhotoHardLimitExceededException(
      variant: variant,
      actualBytes: lastOutputSizeBytes,
      maximumBytes: config.hardMaximumSizeBytes,
    );
  }

  static Future<File> _validateSourceFile(String sourcePath) async {
    final normalizedPath = sourcePath.trim();

    if (normalizedPath.isEmpty || normalizedPath != sourcePath) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'sourcePath must be a non-empty trimmed string.',
      );
    }

    final sourceFile = File(normalizedPath);

    if (!await sourceFile.exists()) {
      throw StateError('Source vessel photo does not exist: $normalizedPath');
    }

    if (await sourceFile.length() <= 0) {
      throw const VesselPhotoProcessingException(
        code: 'source_file_empty',
        message: 'Source vessel photo is empty.',
      );
    }

    return sourceFile;
  }

  static VesselPhotoDimensions _scaleDown({
    required VesselPhotoDimensions dimensions,
    required int maxDimension,
  }) {
    final longestSide = math.max(dimensions.width, dimensions.height);

    if (longestSide <= maxDimension) {
      return dimensions;
    }

    final scale = maxDimension / longestSide;

    return VesselPhotoDimensions(
      width: math.max(1, (dimensions.width * scale).round()),
      height: math.max(1, (dimensions.height * scale).round()),
    );
  }

  static void _validateOutputDimensions({
    required VesselPhotoDimensions sourceDimensions,
    required VesselPhotoDimensions outputDimensions,
    required int maxDimension,
  }) {
    if (!outputDimensions.isValid) {
      throw const VesselPhotoProcessingException(
        code: 'invalid_output_dimensions',
        message: 'Compressed image dimensions are invalid.',
      );
    }

    if (outputDimensions.width > maxDimension ||
        outputDimensions.height > maxDimension) {
      throw VesselPhotoProcessingException(
        code: 'output_dimensions_exceeded',
        message: 'Image exceeds the $maxDimension pixel limit.',
      );
    }

    final difference = _aspectRatioDifferenceAllowingRotation(
      sourceDimensions,
      outputDimensions,
    );

    if (difference > 0.02) {
      throw const VesselPhotoProcessingException(
        code: 'aspect_ratio_changed',
        message: 'Image aspect ratio changed unexpectedly.',
      );
    }
  }

  static void _validateVariantRelationship({
    required _PreparedVesselPhotoVariant thumbnail,
    required _PreparedVesselPhotoVariant full,
  }) {
    if (full.dimensions.width < thumbnail.dimensions.width ||
        full.dimensions.height < thumbnail.dimensions.height) {
      throw const VesselPhotoProcessingException(
        code: 'variant_dimensions_invalid',
        message: 'Full image must not be smaller than thumbnail.',
      );
    }

    final difference =
        (thumbnail.dimensions.aspectRatio - full.dimensions.aspectRatio).abs();

    if (difference > 0.02) {
      throw const VesselPhotoProcessingException(
        code: 'variant_aspect_ratio_mismatch',
        message: 'Thumbnail and full image aspect ratios do not match.',
      );
    }
  }

  static double _aspectRatioDifferenceAllowingRotation(
    VesselPhotoDimensions first,
    VesselPhotoDimensions second,
  ) {
    final directDifference = (first.aspectRatio - second.aspectRatio).abs();

    final rotatedDifference = ((1 / first.aspectRatio) - second.aspectRatio)
        .abs();

    return math.min(directDifference, rotatedDifference);
  }

  static Future<VesselPhotoDimensions> _readImageDimensions(String path) async {
    try {
      final bytes = await File(path).readAsBytes();

      final codec = await ui.instantiateImageCodec(bytes);

      try {
        final frame = await codec.getNextFrame();

        try {
          return VesselPhotoDimensions(
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
        const VesselPhotoProcessingException(
          code: 'image_dimensions_unavailable',
          message: 'Could not read vessel photo dimensions.',
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
      throw VesselPhotoProcessingException(
        code: 'temporary_file_cleanup_failed',
        message: 'Could not delete temporary vessel photo: ${error.message}',
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

final class _PreparedVesselPhotoVariant {
  const _PreparedVesselPhotoVariant({
    required this.path,
    required this.dimensions,
    required this.sizeBytes,
  });

  final String path;
  final VesselPhotoDimensions dimensions;
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
      // Продолжаем cleanup остальных файлов.
    }
  }

  try {
    if (await workingDirectory.exists()) {
      await workingDirectory.delete(recursive: true);
    }
  } catch (_) {
    // Best effort.
  }

  try {
    return !await workingDirectory.exists();
  } catch (_) {
    return false;
  }
}
