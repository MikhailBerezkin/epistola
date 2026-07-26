import 'dart:typed_data';

abstract interface class AvatarImageSource {
  Future<Uint8List?> read({required String path, required int maxSizeBytes});
}

abstract interface class AvatarImageLoader {
  Future<Uint8List?> load({
    required String path,
    required int version,
    required int maxSizeBytes,
  });
}

final class AvatarImageSizeLimitExceededException implements Exception {
  const AvatarImageSizeLimitExceededException({
    required this.actualBytes,
    required this.maximumBytes,
  });

  final int actualBytes;
  final int maximumBytes;

  @override
  String toString() {
    return 'Avatar image is $actualBytes bytes; maximum is '
        '$maximumBytes bytes.';
  }
}
