import 'dart:io';

import '../../domain/models/media_asset.dart';
import 'firebase_media_storage_provider.dart';
import 'media_storage_provider.dart';
import 'media_paths.dart';

class MediaStorageService {
  final MediaStorageProvider _provider;

  MediaStorageService({MediaStorageProvider? provider})
    : _provider = provider ?? FirebaseMediaStorageProvider();

  Future<MediaAsset> uploadUserAvatar({
    required String userId,
    required File file,
    String mimeType = 'image/jpeg',
    int version = 1,
  }) {
    final path = MediaPaths.userAvatar(userId);

    return _provider.uploadFile(
      file: file,
      path: path,
      type: 'userAvatar',
      ownerType: 'user',
      ownerId: userId,
      mimeType: mimeType,
      version: version,
    );
  }

  Future<MediaAsset> uploadGroupAvatar({
    required String chatId,
    required File file,
    String mimeType = 'image/jpeg',
    int version = 1,
  }) {
    final path = MediaPaths.groupAvatar(chatId);

    return _provider.uploadFile(
      file: file,
      path: path,
      type: 'groupAvatar',
      ownerType: 'chat',
      ownerId: chatId,
      mimeType: mimeType,
      version: version,
    );
  }

  Future<String> getDownloadUrl(String path) {
    return _provider.getDownloadUrl(path);
  }

  Future<void> deleteMedia(String path) {
    return _provider.deleteFile(path);
  }
}
