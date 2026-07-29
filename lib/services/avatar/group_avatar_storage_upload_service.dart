import 'dart:io';

import '../../domain/models/group_avatar.dart';
import '../../domain/models/media_asset.dart';
import '../media/media_paths.dart';
import 'avatar_image_pipeline_config.dart';
import 'avatar_image_processor.dart';
import 'avatar_storage_gateway.dart';

final class GroupAvatarStorageUploadService {
  factory GroupAvatarStorageUploadService({
    required AvatarStorageGateway provider,
  }) {
    return GroupAvatarStorageUploadService._(provider);
  }

  GroupAvatarStorageUploadService._(this._provider);

  static const _mimeType = 'image/jpeg';
  static const _ownerType = 'group';

  final AvatarStorageGateway _provider;

  Future<GroupAvatar> upload({
    required String chatId,
    required int version,
    required PreparedAvatarImages images,
  }) async {
    final normalizedChatId = chatId.trim();

    _validateChatId(normalizedChatId);
    _validateVersion(version);

    await _validateImageSize(
      images.thumbnailPath,
      AvatarImagePipelineConfig.hardThumbnailSizeBytes,
    );

    await _validateImageSize(
      images.fullPath,
      AvatarImagePipelineConfig.hardFullSizeBytes,
    );

    final thumbnailPath = MediaPaths.groupAvatarThumbnail(
      chatId: normalizedChatId,
      version: version,
    );

    final fullPath = MediaPaths.groupAvatarFull(
      chatId: normalizedChatId,
      version: version,
    );

    try {
      final thumbnail = await _uploadVariant(
        filePath: images.thumbnailPath,
        storagePath: thumbnailPath,
        type: 'groupAvatarThumbnail',
        chatId: normalizedChatId,
        version: version,
        width: AvatarImagePipelineConfig.thumbnail.width,
        height: AvatarImagePipelineConfig.thumbnail.height,
      );

      final full = await _uploadVariant(
        filePath: images.fullPath,
        storagePath: fullPath,
        type: 'groupAvatarFull',
        chatId: normalizedChatId,
        version: version,
        width: AvatarImagePipelineConfig.full.width,
        height: AvatarImagePipelineConfig.full.height,
      );

      return GroupAvatar(thumbnail: thumbnail, full: full);
    } catch (error, stackTrace) {
      await _deleteBestEffort(thumbnailPath);
      await _deleteBestEffort(fullPath);

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> deleteAvatarVersion({
    required String chatId,
    required GroupAvatar avatar,
    required int activeVersion,
  }) async {
    final normalizedChatId = chatId.trim();

    final belongsToChat =
        avatar.thumbnail.ownerType == _ownerType &&
        avatar.full.ownerType == _ownerType &&
        avatar.thumbnail.ownerId == normalizedChatId &&
        avatar.full.ownerId == normalizedChatId;

    if (normalizedChatId.isEmpty ||
        avatar.version <= 0 ||
        avatar.version == activeVersion ||
        avatar.provider != _provider.providerName ||
        !belongsToChat) {
      return;
    }

    final expectedThumbnailPath = MediaPaths.groupAvatarThumbnail(
      chatId: normalizedChatId,
      version: avatar.version,
    );

    final expectedFullPath = MediaPaths.groupAvatarFull(
      chatId: normalizedChatId,
      version: avatar.version,
    );

    if (avatar.thumbnailStoragePath != expectedThumbnailPath ||
        avatar.fullStoragePath != expectedFullPath) {
      return;
    }

    await _deleteBestEffort(expectedThumbnailPath);
    await _deleteBestEffort(expectedFullPath);
  }

  Future<MediaAsset> _uploadVariant({
    required String filePath,
    required String storagePath,
    required String type,
    required String chatId,
    required int version,
    required int width,
    required int height,
  }) async {
    final asset = await _provider.uploadFile(
      file: File(filePath),
      path: storagePath,
      type: type,
      ownerType: _ownerType,
      ownerId: chatId,
      mimeType: _mimeType,
      version: version,
    );

    return asset.copyWith(
      path: storagePath,
      type: type,
      ownerType: _ownerType,
      ownerId: chatId,
      mimeType: _mimeType,
      width: width,
      height: height,
      version: version,
    );
  }

  Future<void> _deleteBestEffort(String path) async {
    try {
      await _provider.deleteFile(path);
    } catch (_) {
      // Ошибка cleanup не должна заменять исходную ошибку upload.
    }
  }

  static void _validateChatId(String chatId) {
    if (chatId.isEmpty) {
      throw ArgumentError.value(chatId, 'chatId', 'Chat ID must not be empty.');
    }
  }

  static void _validateVersion(int version) {
    if (version <= 0) {
      throw ArgumentError.value(
        version,
        'version',
        'Version must be positive.',
      );
    }
  }

  static Future<void> _validateImageSize(String path, int maximumBytes) async {
    final size = await File(path).length();

    if (size > maximumBytes) {
      throw AvatarImageHardLimitExceededException(
        actualBytes: size,
        maximumBytes: maximumBytes,
      );
    }
  }
}
