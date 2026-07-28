import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/group_avatar.dart';
import '../../domain/models/media_asset.dart';
import '../media/media_paths.dart';

final class GroupAvatarMetadataMapper {
  static const fieldNames = <String>{
    'groupAvatarProvider',
    'groupAvatarThumbStoragePath',
    'groupAvatarFullStoragePath',
    'groupAvatarThumbSizeBytes',
    'groupAvatarFullSizeBytes',
    'groupAvatarVersion',
    'groupAvatarUpdatedAt',
  };

  static GroupAvatar? fromMap({
    required Map<String, dynamic> data,
    required String chatId,
  }) {
    final normalizedChatId = chatId.trim();

    if (normalizedChatId.isEmpty) {
      return null;
    }

    final provider = _readString(data['groupAvatarProvider']);
    final thumbnailPath = _readString(data['groupAvatarThumbStoragePath']);
    final fullPath = _readString(data['groupAvatarFullStoragePath']);
    final thumbnailSize = _readNullableInt(data['groupAvatarThumbSizeBytes']);
    final fullSize = _readNullableInt(data['groupAvatarFullSizeBytes']);
    final version = _readInt(data['groupAvatarVersion']);
    final updatedAt = _readDateTime(data['groupAvatarUpdatedAt']);

    if (provider.isEmpty ||
        thumbnailPath.isEmpty ||
        fullPath.isEmpty ||
        thumbnailSize == null ||
        thumbnailSize < 0 ||
        fullSize == null ||
        fullSize < 0 ||
        version <= 0 ||
        updatedAt == null) {
      return null;
    }

    final expectedThumbnailPath = MediaPaths.groupAvatarThumbnail(
      chatId: normalizedChatId,
      version: version,
    );
    final expectedFullPath = MediaPaths.groupAvatarFull(
      chatId: normalizedChatId,
      version: version,
    );

    if (thumbnailPath != expectedThumbnailPath ||
        fullPath != expectedFullPath) {
      return null;
    }

    final avatar = GroupAvatar(
      thumbnail: MediaAsset(
        id: 'group-avatar-$normalizedChatId-v$version-thumb',
        provider: provider,
        path: thumbnailPath,
        type: 'groupAvatarThumbnail',
        ownerType: 'group',
        ownerId: normalizedChatId,
        mimeType: 'image/jpeg',
        sizeBytes: thumbnailSize,
        version: version,
        updatedAt: updatedAt,
      ),
      full: MediaAsset(
        id: 'group-avatar-$normalizedChatId-v$version-full',
        provider: provider,
        path: fullPath,
        type: 'groupAvatarFull',
        ownerType: 'group',
        ownerId: normalizedChatId,
        mimeType: 'image/jpeg',
        sizeBytes: fullSize,
        version: version,
        updatedAt: updatedAt,
      ),
    );

    return avatar.isComplete ? avatar : null;
  }

  static Map<String, dynamic> toMap({
    required String chatId,
    required GroupAvatar avatar,
  }) {
    final normalizedChatId = chatId.trim();

    if (normalizedChatId.isEmpty) {
      throw ArgumentError.value(chatId, 'chatId', 'Chat ID must not be empty.');
    }

    if (!avatar.hasPersistableMetadata) {
      throw ArgumentError.value(
        avatar,
        'avatar',
        'Group avatar metadata must be complete.',
      );
    }

    final expectedThumbnailPath = MediaPaths.groupAvatarThumbnail(
      chatId: normalizedChatId,
      version: avatar.version,
    );
    final expectedFullPath = MediaPaths.groupAvatarFull(
      chatId: normalizedChatId,
      version: avatar.version,
    );

    final ownsChat =
        avatar.thumbnail.ownerType == 'group' &&
        avatar.full.ownerType == 'group' &&
        avatar.thumbnail.ownerId == normalizedChatId &&
        avatar.full.ownerId == normalizedChatId;

    final usesExpectedPaths =
        avatar.thumbnailStoragePath == expectedThumbnailPath &&
        avatar.fullStoragePath == expectedFullPath;

    if (!ownsChat || !usesExpectedPaths) {
      throw ArgumentError.value(
        avatar,
        'avatar',
        'Group avatar must belong to the target chat.',
      );
    }

    return {
      'groupAvatarProvider': avatar.provider,
      'groupAvatarThumbStoragePath': avatar.thumbnailStoragePath,
      'groupAvatarFullStoragePath': avatar.fullStoragePath,
      'groupAvatarThumbSizeBytes': avatar.thumbnailSizeBytes,
      'groupAvatarFullSizeBytes': avatar.fullSizeBytes,
      'groupAvatarVersion': avatar.version,
      'groupAvatarUpdatedAt': avatar.updatedAt,
    };
  }

  static String _readString(dynamic value) {
    return value is String ? value.trim() : '';
  }

  static int _readInt(dynamic value) {
    return value is num ? value.toInt() : 0;
  }

  static int? _readNullableInt(dynamic value) {
    return value is num ? value.toInt() : null;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
