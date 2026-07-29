import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/models/media_asset.dart';
import 'avatar_storage_gateway.dart';

typedef AvatarStorageUploadInvoker =
    Future<AvatarStorageUploadResult> Function({
      required File file,
      required String path,
      required String type,
      required String ownerType,
      required String ownerId,
      required String mimeType,
      required int version,
    });

typedef AvatarStorageDeleteInvoker = Future<void> Function(String path);

final class AvatarStorageUploadResult {
  const AvatarStorageUploadResult({
    required this.sizeBytes,
    required this.createdAt,
    required this.updatedAt,
  });

  final int sizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class FirebaseAvatarStorageGateway implements AvatarStorageGateway {
  FirebaseAvatarStorageGateway({
    AvatarStorageUploadInvoker? uploadInvoker,
    AvatarStorageDeleteInvoker? deleteInvoker,
  }) : _uploadInvoker = uploadInvoker ?? _uploadWithFirebaseStorage,
       _deleteInvoker = deleteInvoker ?? _deleteWithFirebaseStorage;

  final AvatarStorageUploadInvoker _uploadInvoker;
  final AvatarStorageDeleteInvoker _deleteInvoker;

  @override
  String get providerName => 'firebase';

  @override
  Future<MediaAsset> uploadFile({
    required File file,
    required String path,
    required String type,
    required String ownerType,
    required String ownerId,
    required String mimeType,
    required int version,
  }) async {
    final result = await _uploadInvoker(
      file: file,
      path: path,
      type: type,
      ownerType: ownerType,
      ownerId: ownerId,
      mimeType: mimeType,
      version: version,
    );

    return MediaAsset(
      id: path,
      provider: providerName,
      path: path,
      type: type,
      ownerType: ownerType,
      ownerId: ownerId,
      mimeType: mimeType,
      sizeBytes: result.sizeBytes,
      version: version,
      createdAt: result.createdAt,
      updatedAt: result.updatedAt,
    );
  }

  @override
  Future<void> deleteFile(String path) => _deleteInvoker(path);

  static Future<AvatarStorageUploadResult> _uploadWithFirebaseStorage({
    required File file,
    required String path,
    required String type,
    required String ownerType,
    required String ownerId,
    required String mimeType,
    required int version,
  }) async {
    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: {
        'type': type,
        'ownerType': ownerType,
        'ownerId': ownerId,
        'version': version.toString(),
      },
    );

    await FirebaseStorage.instance.ref(path).putFile(file, metadata);

    final now = DateTime.now();
    return AvatarStorageUploadResult(
      sizeBytes: await file.length(),
      createdAt: now,
      updatedAt: now,
    );
  }

  static Future<void> _deleteWithFirebaseStorage(String path) {
    return FirebaseStorage.instance.ref(path).delete();
  }
}
