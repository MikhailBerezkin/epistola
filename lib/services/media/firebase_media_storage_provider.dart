import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/models/media_asset.dart';
import 'media_storage_provider.dart';

class FirebaseMediaStorageProvider implements MediaStorageProvider {
  final FirebaseStorage _storage;

  FirebaseMediaStorageProvider({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  @override
  String get providerName => 'firebase';

  @override
  Future<MediaAsset> uploadFile({
    required File file,
    required String path,
    required String type,
    String? ownerType,
    String? ownerId,
    String? mimeType,
    int version = 1,
  }) async {
    final ref = _storage.ref(path);

    final customMetadata = <String, String>{
      'type': type,
      'version': version.toString(),
    };

    if (ownerType != null) {
      customMetadata['ownerType'] = ownerType;
    }

    if (ownerId != null) {
      customMetadata['ownerId'] = ownerId;
    }

    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: customMetadata,
    );

    final uploadTask = await ref.putFile(file, metadata);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    final now = DateTime.now();

    return MediaAsset(
      id: path,
      provider: providerName,
      path: path,
      type: type,
      ownerType: ownerType,
      ownerId: ownerId,
      mimeType: mimeType,
      sizeBytes: await file.length(),
      version: version,
      createdAt: now,
      updatedAt: now,
      downloadUrl: downloadUrl,
    );
  }

  @override
  Future<String> getDownloadUrl(String path) {
    return _storage.ref(path).getDownloadURL();
  }

  @override
  Future<void> deleteFile(String path) {
    return _storage.ref(path).delete();
  }
}
