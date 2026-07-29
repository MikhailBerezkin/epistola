import 'dart:io';

import '../../domain/models/media_asset.dart';

abstract interface class AvatarStorageGateway {
  String get providerName;

  Future<MediaAsset> uploadFile({
    required File file,
    required String path,
    required String type,
    required String ownerType,
    required String ownerId,
    required String mimeType,
    required int version,
  });

  Future<void> deleteFile(String path);
}
