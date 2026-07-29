import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'avatar_image_loader.dart';

typedef AvatarImageReadInvoker =
    Future<Uint8List?> Function({
      required String path,
      required int maxSizeBytes,
    });

final class FirebaseAvatarImageSource implements AvatarImageSource {
  FirebaseAvatarImageSource({AvatarImageReadInvoker? readInvoker})
    : _readInvoker = readInvoker ?? _readWithFirebaseStorage;

  final AvatarImageReadInvoker _readInvoker;

  @override
  Future<Uint8List?> read({required String path, required int maxSizeBytes}) {
    return _readInvoker(path: path, maxSizeBytes: maxSizeBytes);
  }

  static Future<Uint8List?> _readWithFirebaseStorage({
    required String path,
    required int maxSizeBytes,
  }) {
    return FirebaseStorage.instance.ref(path).getData(maxSizeBytes);
  }
}
