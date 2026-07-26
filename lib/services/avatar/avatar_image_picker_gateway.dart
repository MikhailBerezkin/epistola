enum AvatarImagePickSource { gallery, camera }

final class AvatarPickedImage {
  const AvatarPickedImage({required this.path});

  final String path;
}

final class AvatarLostDataRecoveryException implements Exception {
  const AvatarLostDataRecoveryException({required this.code, this.message});

  final String code;
  final String? message;

  @override
  String toString() {
    final description = message;
    return description == null || description.isEmpty
        ? 'AvatarLostDataRecoveryException($code)'
        : 'AvatarLostDataRecoveryException($code): $description';
  }
}

abstract interface class AvatarImagePickerGateway {
  Future<AvatarPickedImage?> pickImage(AvatarImagePickSource source);

  Future<List<AvatarPickedImage>> retrieveLostImages();
}
