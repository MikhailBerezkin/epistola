import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/domain/models/user_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserAvatar', () {
    test('combines thumbnail and full MediaAsset objects', () {
      final updatedAt = DateTime.utc(2026, 7, 26, 12, 30);

      final avatar = UserAvatar(
        thumbnail: MediaAsset(
          id: 'user-1-avatar-v3-thumb',
          provider: 'firebase',
          path: 'user_avatars/user-1/v3/thumb.jpg',
          type: 'userAvatarThumbnail',
          ownerType: 'user',
          ownerId: 'user-1',
          mimeType: 'image/jpeg',
          sizeBytes: 24000,
          width: 128,
          height: 128,
          version: 3,
          updatedAt: updatedAt,
          downloadUrl: 'https://example.com/thumb.jpg',
        ),
        full: MediaAsset(
          id: 'user-1-avatar-v3-full',
          provider: 'firebase',
          path: 'user_avatars/user-1/v3/full.jpg',
          type: 'userAvatarFull',
          ownerType: 'user',
          ownerId: 'user-1',
          mimeType: 'image/jpeg',
          sizeBytes: 180000,
          width: 512,
          height: 512,
          version: 3,
          updatedAt: updatedAt,
          downloadUrl: 'https://example.com/full.jpg',
        ),
      );

      expect(avatar.version, 3);
      expect(avatar.provider, 'firebase');
      expect(avatar.updatedAt, updatedAt);
      expect(avatar.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(avatar.fullUrl, 'https://example.com/full.jpg');
      expect(avatar.thumbnailStoragePath, 'user_avatars/user-1/v3/thumb.jpg');
      expect(avatar.fullStoragePath, 'user_avatars/user-1/v3/full.jpg');
      expect(avatar.isComplete, isTrue);
    });

    test('builds versioned cache keys', () {
      final avatar = UserAvatar(
        thumbnail: _asset(
          id: 'thumb',
          path: 'user_avatars/user-42/v7/thumb.jpg',
          version: 7,
          downloadUrl: 'https://example.com/thumb.jpg',
        ),
        full: _asset(
          id: 'full',
          path: 'user_avatars/user-42/v7/full.jpg',
          version: 7,
          downloadUrl: 'https://example.com/full.jpg',
        ),
      );

      expect(
        avatar.thumbnailCacheKey('user-42'),
        'user-avatar:user-42:v7:thumb',
      );
      expect(avatar.fullCacheKey('user-42'), 'user-avatar:user-42:v7:full');
    });

    test('is incomplete when versions do not match', () {
      final avatar = UserAvatar(
        thumbnail: _asset(
          id: 'thumb',
          path: 'user_avatars/user-1/v2/thumb.jpg',
          version: 2,
          downloadUrl: 'https://example.com/thumb.jpg',
        ),
        full: _asset(
          id: 'full',
          path: 'user_avatars/user-1/v3/full.jpg',
          version: 3,
          downloadUrl: 'https://example.com/full.jpg',
        ),
      );

      expect(avatar.isComplete, isFalse);
    });

    test('is incomplete when one URL is missing', () {
      final avatar = UserAvatar(
        thumbnail: _asset(
          id: 'thumb',
          path: 'user_avatars/user-1/v3/thumb.jpg',
          version: 3,
          downloadUrl: null,
        ),
        full: _asset(
          id: 'full',
          path: 'user_avatars/user-1/v3/full.jpg',
          version: 3,
          downloadUrl: 'https://example.com/full.jpg',
        ),
      );

      expect(avatar.hasThumbnail, isFalse);
      expect(avatar.hasFullImage, isTrue);
      expect(avatar.isComplete, isFalse);
    });
    test('is incomplete when owner is missing', () {
      final avatar = UserAvatar(
        thumbnail: MediaAsset(
          id: 'thumb',
          provider: 'firebase',
          path: 'user_avatars/user-1/v3/thumb.jpg',
          type: 'userAvatar',
          mimeType: 'image/jpeg',
          version: 3,
          downloadUrl: 'https://example.com/thumb.jpg',
        ),
        full: MediaAsset(
          id: 'full',
          provider: 'firebase',
          path: 'user_avatars/user-1/v3/full.jpg',
          type: 'userAvatar',
          mimeType: 'image/jpeg',
          version: 3,
          downloadUrl: 'https://example.com/full.jpg',
        ),
      );

      expect(avatar.isComplete, isFalse);
    });
  });
}

MediaAsset _asset({
  required String id,
  required String path,
  required int version,
  required String? downloadUrl,
}) {
  return MediaAsset(
    id: id,
    provider: 'firebase',
    path: path,
    type: 'userAvatar',
    ownerType: 'user',
    ownerId: 'user-1',
    mimeType: 'image/jpeg',
    version: version,
    downloadUrl: downloadUrl,
  );
}
