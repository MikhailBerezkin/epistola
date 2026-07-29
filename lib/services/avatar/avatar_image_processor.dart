import 'dart:async';
import 'dart:io';

import 'avatar_compression_policy.dart';
import 'avatar_image_compressor_gateway.dart';
import 'avatar_image_pipeline_config.dart';
import 'flutter_image_compress_avatar_image_compressor_gateway.dart';

typedef AvatarImageCleanupInvoker =
    Future<bool> Function({
      required Directory workingDirectory,
      required Iterable<String> filePaths,
    });

final class AvatarImageProcessorException implements Exception {
  const AvatarImageProcessorException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => 'AvatarImageProcessorException($code): $message';
}

final class AvatarImageHardLimitExceededException implements Exception {
  const AvatarImageHardLimitExceededException({
    required this.actualBytes,
    required this.maximumBytes,
  });

  final int actualBytes;
  final int maximumBytes;

  @override
  String toString() {
    return 'AvatarImageHardLimitExceededException: '
        '$actualBytes bytes exceeds the $maximumBytes byte hard limit.';
  }
}

final class PreparedAvatarImages {
  PreparedAvatarImages._({
    required this.thumbnailPath,
    required this.fullPath,
    required this._workingDirectory,
    required this._cleanupInvoker,
  });

  final String thumbnailPath;
  final String fullPath;
  final Directory _workingDirectory;
  final AvatarImageCleanupInvoker _cleanupInvoker;
  Future<void>? _cleanupInFlight;
  bool _isCleaned = false;

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
      // A later cleanup call must be able to retry a transient failure.
    } finally {
      _cleanupInFlight = null;
    }
  }
}

class AvatarImageProcessor {
  AvatarImageProcessor({
    AvatarImageCompressorGateway? compressor,
    this._cleanupInvoker = _cleanupOwnedFiles,
  }) : _compressor =
           compressor ?? FlutterImageCompressAvatarImageCompressorGateway();

  static const _temporaryDirectoryPrefix = 'epistola_avatar_';

  final AvatarImageCompressorGateway _compressor;
  final AvatarImageCleanupInvoker _cleanupInvoker;

  Future<PreparedAvatarImages> process(String sourcePath) async {
    _validateSourcePath(sourcePath);

    final workingDirectory = await Directory.systemTemp.createTemp(
      _temporaryDirectoryPrefix,
    );
    final thumbnailPath = _childPath(workingDirectory, 'thumbnail.jpg');
    String? acceptedFullPath;

    try {
      await _compressVariant(
        sourcePath: sourcePath,
        targetPath: thumbnailPath,
        config: AvatarImagePipelineConfig.thumbnail,
        quality: AvatarImagePipelineConfig.thumbnail.qualityAttempts.single,
      );

      final qualities = AvatarImagePipelineConfig.full.qualityAttempts;

      for (
        var attemptIndex = 0;
        attemptIndex < qualities.length;
        attemptIndex++
      ) {
        final fullPath = _childPath(workingDirectory, 'full_$attemptIndex.jpg');
        final output = await _compressVariant(
          sourcePath: sourcePath,
          targetPath: fullPath,
          config: AvatarImagePipelineConfig.full,
          quality: qualities[attemptIndex],
        );
        final outputSize = await File(output.path).length();
        final decision = AvatarCompressionPolicy.evaluateFullImage(
          fileSizeBytes: outputSize,
          qualityAttemptIndex: attemptIndex,
        );

        switch (decision) {
          case AvatarCompressionDecision.accept:
            acceptedFullPath = output.path;
          case AvatarCompressionDecision.recompress:
            await _deleteRejectedAttempt(output.path);
          case AvatarCompressionDecision.hardMaximumExceeded:
            throw AvatarImageHardLimitExceededException(
              actualBytes: outputSize,
              maximumBytes: AvatarImagePipelineConfig.hardFullSizeBytes,
            );
        }

        if (acceptedFullPath != null) {
          break;
        }
      }

      final fullPath = acceptedFullPath;

      if (fullPath == null) {
        throw const AvatarImageProcessorException(
          code: 'full_output_missing',
          message: 'Avatar full image was not produced.',
        );
      }

      return PreparedAvatarImages._(
        thumbnailPath: thumbnailPath,
        fullPath: fullPath,
        workingDirectory: workingDirectory,
        cleanupInvoker: _cleanupInvoker,
      );
    } catch (error, stackTrace) {
      try {
        await _cleanupInvoker(
          workingDirectory: workingDirectory,
          filePaths: [thumbnailPath, ?acceptedFullPath],
        );
      } catch (_) {
        // Cleanup must never replace the original processing failure.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<AvatarCompressedImage> _compressVariant({
    required String sourcePath,
    required String targetPath,
    required AvatarImageVariantConfig config,
    required int quality,
  }) async {
    final output = await _compressor.compress(
      AvatarImageCompressionRequest(
        sourcePath: sourcePath,
        targetPath: targetPath,
        format: config.format,
        width: config.width,
        height: config.height,
        quality: quality,
        keepExif: false,
        autoCorrectionAngle: true,
        rotate: 0,
      ),
    );

    if (output == null || output.path.trim().isEmpty) {
      throw const AvatarImageProcessorException(
        code: 'compression_output_missing',
        message: 'Avatar compressor returned no output.',
      );
    }

    if (!_samePath(output.path, targetPath)) {
      throw const AvatarImageProcessorException(
        code: 'unexpected_output_path',
        message: 'Avatar compressor returned an unexpected output path.',
      );
    }

    if (!await File(output.path).exists()) {
      throw const AvatarImageProcessorException(
        code: 'compression_output_missing',
        message: 'Avatar compressor output does not exist.',
      );
    }

    return output;
  }

  static Future<void> _deleteRejectedAttempt(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException catch (error) {
      throw AvatarImageProcessorException(
        code: 'temporary_file_cleanup_failed',
        message: 'Could not delete a rejected avatar image: ${error.message}',
      );
    }
  }

  static String _childPath(Directory directory, String fileName) {
    return '${directory.path}${Platform.pathSeparator}$fileName';
  }

  static bool _samePath(String first, String second) {
    return File(first).absolute.uri.normalizePath() ==
        File(second).absolute.uri.normalizePath();
  }

  static void _validateSourcePath(String sourcePath) {
    if (sourcePath.trim().isEmpty) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'Source path must not be empty.',
      );
    }
  }
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
      // Continue cleanup so one failed file cannot strand the other outputs.
    }
  }

  try {
    if (await workingDirectory.exists()) {
      await workingDirectory.delete(recursive: true);
    }
  } catch (_) {
    // Cleanup is best-effort and must remain idempotent.
  }

  try {
    return !await workingDirectory.exists();
  } catch (_) {
    return false;
  }
}
