import 'dart:io';

import '../../domain/models/media_asset.dart';
import '../chat/image_message_remote_cleanup_service.dart';

abstract interface class ImageMessageStorageGateway
    implements ImageMessageRemoteCleanupGateway {
  Future<MediaAsset> uploadThumbnail({
    required File file,
    required String uploaderId,
    required String chatId,
    required String messageId,
    required int version,
    required int width,
    required int height,
    bool usesFirstPrivateImageGrant = false,
  });

  Future<MediaAsset> uploadFull({
    required File file,
    required String uploaderId,
    required String chatId,
    required String messageId,
    required int version,
    required int width,
    required int height,
    bool usesFirstPrivateImageGrant = false,
  });
}
