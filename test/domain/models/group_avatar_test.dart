import 'package:epistola/domain/models/group_avatar.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupAvatar', () {
    test('combines thumbnail and full group assets', () {
      final updatedAt = DateTime.utc(2026, 7, 28, 12, 30);

      final avatar = GroupAvatar(
        thumbnail: _asset(
          id: 'group-1-avatar-v3-thumb',
          path: 'group_avatars/group-1/v3/thumb.jpg',
          type: 'groupAvatarThumbnail',
          version: 3,
          sizeBytes: 24000,
          updatedAt: updatedAt,
        ),
        full: _asset(
          id: 'group-1-avatar-v3-full',
          path: 'group_avatars/group-1/v3/full.jpg',
          type: 'groupAvatarFull',
          version: 3,
          sizeBytes: 180000,
          updatedAt: updatedAt,
        ),
      );

      expect(avatar.version, 3);
      expect(avatar.provider, 'firebase');
      expect(avatar.thumbnailStoragePath, 'group_avatars/group-1/v3/thumb.jpg');
      expect(avatar.fullStoragePath, 'group_avatars/group-1/v3/full.jpg');
      expect(avatar.isComplete, isTrue);
      expect(avatar.hasPersistableMetadata, isTrue);
    });

    test('builds versioned group cache keys', () {
      final avatar = GroupAvatar(
        thumbnail: _asset(
          id: 'thumb',
          path: 'group_avatars/group-42/v7/thumb.jpg',
          type: 'groupAvatarThumbnail',
          version: 7,
        ),
        full: _asset(
          id: 'full',
          path: 'group_avatars/group-42/v7/full.jpg',
          type: 'groupAvatarFull',
          version: 7,
        ),
      );

      expect(
        avatar.thumbnailCacheKey('group-42'),
        'group-avatar:group-42:v7:thumb',
      );
      expect(avatar.fullCacheKey('group-42'), 'group-avatar:group-42:v7:full');
    });

    test('is incomplete when owner type is not group', () {
      final avatar = GroupAvatar(
        thumbnail: _asset(
          id: 'thumb',
          path: 'group_avatars/group-1/v3/thumb.jpg',
          type: 'groupAvatarThumbnail',
          version: 3,
          ownerType: 'user',
        ),
        full: _asset(
          id: 'full',
          path: 'group_avatars/group-1/v3/full.jpg',
          type: 'groupAvatarFull',
          version: 3,
          ownerType: 'user',
        ),
      );

      expect(avatar.isComplete, isFalse);
    });
  });
}

MediaAsset _asset({
  required String id,
  required String path,
  required String type,
  required int version,
  String ownerType = 'group',
  int? sizeBytes,
  DateTime? updatedAt,
}) {
  return MediaAsset(
    id: id,
    provider: 'firebase',
    path: path,
    type: type,
    ownerType: ownerType,
    ownerId: 'group-1',
    mimeType: 'image/jpeg',
    sizeBytes: sizeBytes,
    version: version,
    updatedAt: updatedAt,
  );
}
