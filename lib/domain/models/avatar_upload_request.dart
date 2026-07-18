import 'dart:typed_data';

class AvatarUploadRequest {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const AvatarUploadRequest({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}
