import 'dart:io';

import '../../domain/models/media_asset.dart';
import '../../domain/models/user_avatar.dart';
import '../media/media_paths.dart';
import '../media/media_storage_provider.dart';
import 'avatar_image_pipeline_config.dart';
import 'avatar_image_processor.dart';

final class AvatarStorageUploadService {
  factory AvatarStorageUploadService({
    required MediaStorageProvider provider,
  }) {
    return AvatarStorageUploadService._(provider);
  }

  AvatarStorageUploadService._(this._provider);

  static const _mimeType = 'image/jpeg';
  static const _ownerType = 'user';

  final MediaStorageProvider _provider;

  Future<UserAvatar> upload({
    required String uid,
    required int version,
    required PreparedAvatarImages images,
  }) async {
    _validateUid(uid);
    _validateVersion(version);
    await _validateFullImageSize(images.fullPath);

    final thumbnailPath = MediaPaths.userAvatarThumbnail(
      userId: uid,
      version: version,
    );
    final fullPath = MediaPaths.userAvatarFull(userId: uid, version: version);

    try {
      final thumbnail = await _uploadVariant(
        filePath: images.thumbnailPath,
        storagePath: thumbnailPath,
        type: 'userAvatarThumbnail',
        uid: uid,
        version: version,
        width: AvatarImagePipelineConfig.thumbnail.width,
        height: AvatarImagePipelineConfig.thumbnail.height,
      );
      final full = await _uploadVariant(
        filePath: images.fullPath,
        storagePath: fullPath,
        type: 'userAvatarFull',
        uid: uid,
        version: version,
        width: AvatarImagePipelineConfig.full.width,
        height: AvatarImagePipelineConfig.full.height,
      );

      return UserAvatar(thumbnail: thumbnail, full: full);
    } catch (error, stackTrace) {
      await _deleteBestEffort(thumbnailPath);
      await _deleteBestEffort(fullPath);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<MediaAsset> _uploadVariant({
    required String filePath,
    required String storagePath,
    required String type,
    required String uid,
    required int version,
    required int width,
    required int height,
  }) async {
    final asset = await _provider.uploadFile(
      file: File(filePath),
      path: storagePath,
      type: type,
      ownerType: _ownerType,
      ownerId: uid,
      mimeType: _mimeType,
      version: version,
    );

    return asset.copyWith(
      path: storagePath,
      type: type,
      ownerType: _ownerType,
      ownerId: uid,
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
      // Cleanup failures must not replace the upload failure.
    }
  }

  static void _validateUid(String uid) {
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'UID must not be empty.');
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

  static Future<void> _validateFullImageSize(String fullPath) async {
    final fullSize = await File(fullPath).length();

    if (fullSize > AvatarImagePipelineConfig.hardFullSizeBytes) {
      throw AvatarImageHardLimitExceededException(
        actualBytes: fullSize,
        maximumBytes: AvatarImagePipelineConfig.hardFullSizeBytes,
      );
    }
  }
}
