import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'avatar_image_compressor_gateway.dart';
import 'avatar_image_pipeline_config.dart';

typedef AvatarImageCompressInvoker =
    Future<String?> Function(AvatarImageCompressionRequest request);

final class FlutterImageCompressAvatarImageCompressorGateway
    implements AvatarImageCompressorGateway {
  FlutterImageCompressAvatarImageCompressorGateway({
    AvatarImageCompressInvoker? invoker,
  }) : _invoker = invoker ?? _invokeFlutterImageCompress;

  static const _fallbackErrorCode = 'compression_failed';
  static const _fallbackErrorMessage = 'Failed to compress the avatar image.';

  final AvatarImageCompressInvoker _invoker;

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    try {
      final outputPath = await _invoker(request);
      return outputPath == null
          ? null
          : AvatarCompressedImage(path: outputPath);
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AvatarImageCompressorException(
          code: error.code.isEmpty ? _fallbackErrorCode : error.code,
          message: _messageOrFallback(error.message),
        ),
        stackTrace,
      );
    } on AvatarImageCompressorException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        const AvatarImageCompressorException(
          code: _fallbackErrorCode,
          message: _fallbackErrorMessage,
        ),
        stackTrace,
      );
    }
  }

  static Future<String?> _invokeFlutterImageCompress(
    AvatarImageCompressionRequest request,
  ) async {
    final output = await FlutterImageCompress.compressAndGetFile(
      request.sourcePath,
      request.targetPath,
      minWidth: request.width,
      minHeight: request.height,
      quality: request.quality,
      rotate: request.rotate,
      autoCorrectionAngle: request.autoCorrectionAngle,
      format: _mapFormat(request.format),
      keepExif: request.keepExif,
    );

    return output?.path;
  }

  static CompressFormat _mapFormat(AvatarImageFormat format) {
    return switch (format) {
      AvatarImageFormat.jpeg => CompressFormat.jpeg,
    };
  }

  static String _messageOrFallback(String? message) {
    return message == null || message.trim().isEmpty
        ? _fallbackErrorMessage
        : message;
  }
}
