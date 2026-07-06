import 'dart:io';

import '../../domain/models/media_asset.dart';

abstract class MediaStorageProvider {
  String get providerName;

  Future<MediaAsset> uploadFile({
    required File file,
    required String path,
    required String type,
    String? ownerType,
    String? ownerId,
    String? mimeType,
    int version = 1,
  });

  Future<String> getDownloadUrl(String path);

  Future<void> deleteFile(String path);
}
