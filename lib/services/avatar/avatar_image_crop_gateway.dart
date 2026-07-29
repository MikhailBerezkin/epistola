final class AvatarCroppedImage {
  const AvatarCroppedImage({required this.path});

  final String path;
}

final class AvatarImageCropException implements Exception {
  const AvatarImageCropException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'AvatarImageCropException($code): $message';
}

abstract interface class AvatarImageCropGateway {
  Future<AvatarCroppedImage?> cropSquare(String sourcePath);
}
