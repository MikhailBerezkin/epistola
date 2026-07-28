import 'package:epistola/domain/models/group_avatar.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/services/avatar/group_avatar_metadata_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupAvatarMetadataMapper', () {
    test('reads valid path-first metadata', () {
      final updatedAt = DateTime.utc(2026, 7, 28, 14, 30);

      final avatar = GroupAvatarMetadataMapper.fromMap(
        chatId: 'group-1',
        data: {
          'groupAvatarProvider': 'firebase',
          'groupAvatarThumbStoragePath': 'group_avatars/group-1/v7/thumb.jpg',
          'groupAvatarFullStoragePath': 'group_avatars/group-1/v7/full.jpg',
          'groupAvatarThumbSizeBytes': 24000,
          'groupAvatarFullSizeBytes': 180000,
          'groupAvatarVersion': 7,
          'groupAvatarUpdatedAt': updatedAt,
        },
      );

      expect(avatar, isNotNull);
      expect(avatar!.version, 7);
      expect(avatar.provider, 'firebase');
      expect(avatar.updatedAt, updatedAt);
      expect(avatar.isComplete, isTrue);
      expect(avatar.hasPersistableMetadata, isTrue);
    });

    test('rejects metadata with another group path', () {
      final avatar = GroupAvatarMetadataMapper.fromMap(
        chatId: 'group-1',
        data: {
          'groupAvatarProvider': 'firebase',
          'groupAvatarThumbStoragePath': 'group_avatars/group-2/v7/thumb.jpg',
          'groupAvatarFullStoragePath': 'group_avatars/group-2/v7/full.jpg',
          'groupAvatarThumbSizeBytes': 24000,
          'groupAvatarFullSizeBytes': 180000,
          'groupAvatarVersion': 7,
          'groupAvatarUpdatedAt': DateTime.utc(2026, 7, 28),
        },
      );

      expect(avatar, isNull);
    });

    test('writes complete metadata', () {
      final updatedAt = DateTime.utc(2026, 7, 28, 14, 30);

      final metadata = GroupAvatarMetadataMapper.toMap(
        chatId: 'group-1',
        avatar: GroupAvatar(
          thumbnail: _asset(
            id: 'thumb',
            path: 'group_avatars/group-1/v9/thumb.jpg',
            type: 'groupAvatarThumbnail',
            version: 9,
            sizeBytes: 24000,
            updatedAt: updatedAt,
          ),
          full: _asset(
            id: 'full',
            path: 'group_avatars/group-1/v9/full.jpg',
            type: 'groupAvatarFull',
            version: 9,
            sizeBytes: 180000,
            updatedAt: updatedAt,
          ),
        ),
      );

      expect(metadata, {
        'groupAvatarProvider': 'firebase',
        'groupAvatarThumbStoragePath': 'group_avatars/group-1/v9/thumb.jpg',
        'groupAvatarFullStoragePath': 'group_avatars/group-1/v9/full.jpg',
        'groupAvatarThumbSizeBytes': 24000,
        'groupAvatarFullSizeBytes': 180000,
        'groupAvatarVersion': 9,
        'groupAvatarUpdatedAt': updatedAt,
      });
    });

    test('rejects incomplete metadata when writing', () {
      final avatar = GroupAvatar(
        thumbnail: _asset(
          id: 'thumb',
          path: 'group_avatars/group-1/v9/thumb.jpg',
          type: 'groupAvatarThumbnail',
          version: 9,
        ),
        full: _asset(
          id: 'full',
          path: 'group_avatars/group-1/v9/full.jpg',
          type: 'groupAvatarFull',
          version: 9,
        ),
      );

      expect(
        () =>
            GroupAvatarMetadataMapper.toMap(chatId: 'group-1', avatar: avatar),
        throwsArgumentError,
      );
    });
  });
}

MediaAsset _asset({
  required String id,
  required String path,
  required String type,
  required int version,
  int? sizeBytes,
  DateTime? updatedAt,
}) {
  return MediaAsset(
    id: id,
    provider: 'firebase',
    path: path,
    type: type,
    ownerType: 'group',
    ownerId: 'group-1',
    mimeType: 'image/jpeg',
    sizeBytes: sizeBytes,
    version: version,
    updatedAt: updatedAt,
  );
}
