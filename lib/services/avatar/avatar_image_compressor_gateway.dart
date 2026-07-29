import 'avatar_image_pipeline_config.dart';

final class AvatarImageCompressionRequest {
  const AvatarImageCompressionRequest({
    required this.sourcePath,
    required this.targetPath,
    required this.format,
    required this.width,
    required this.height,
    required this.quality,
    required this.keepExif,
    required this.autoCorrectionAngle,
    required this.rotate,
  });

  final String sourcePath;
  final String targetPath;
  final AvatarImageFormat format;
  final int width;
  final int height;
  final int quality;
  final bool keepExif;
  final bool autoCorrectionAngle;
  final int rotate;
}

final class AvatarCompressedImage {
  const AvatarCompressedImage({required this.path});

  final String path;
}

final class AvatarImageCompressorException implements Exception {
  const AvatarImageCompressorException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => 'AvatarImageCompressorException($code): $message';
}

abstract interface class AvatarImageCompressorGateway {
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  );
}
