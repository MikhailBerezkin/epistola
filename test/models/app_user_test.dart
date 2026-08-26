import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/domain/models/user_avatar.dart';
import 'package:epistola/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUser avatars', () {
    test('reads legacy URL-bearing avatar metadata from the user document', () {
      final updatedAt = DateTime.utc(2026, 7, 26, 12, 30);

      final user = AppUser.fromMap({
        'uid': 'user-1',
        'email': 'user@example.com',
        'name': 'Иван Иванов',
        'phone': '',
        'about': '',
        'avatarProvider': 'firebase',
        'avatarThumbUrl': 'https://example.com/thumb.jpg',
        'avatarFullUrl': 'https://example.com/full.jpg',
        'avatarThumbStoragePath': 'user_avatars/user-1/v3/thumb.jpg',
        'avatarFullStoragePath': 'user_avatars/user-1/v3/full.jpg',
        'avatarVersion': 3,
        'avatarUpdatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(user.avatar, isNotNull);
      expect(user.avatar!.version, 3);
      expect(user.avatar!.provider, 'firebase');
      expect(user.avatar!.updatedAt?.toUtc(), updatedAt);
      expect(user.avatar!.isComplete, isTrue);
      expect(user.effectiveAvatarThumbnailUrl, 'https://example.com/thumb.jpg');
      expect(user.effectiveAvatarFullUrl, 'https://example.com/full.jpg');
      expect(user.hasAvatar, isTrue);
    });

    test('reads path-first avatar metadata without bearer URLs', () {
      final updatedAt = DateTime.utc(2026, 7, 26, 12, 45);

      final user = AppUser.fromMap({
        'uid': 'user-1',
        'email': 'user@example.com',
        'name': 'Иван Иванов',
        'phone': '',
        'about': '',
        'avatarProvider': 'firebase',
        'avatarThumbStoragePath': 'user_avatars/user-1/v4/thumb.jpg',
        'avatarFullStoragePath': 'user_avatars/user-1/v4/full.jpg',
        'avatarThumbSizeBytes': 24000,
        'avatarFullSizeBytes': 180000,
        'avatarVersion': 4,
        'avatarUpdatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(user.avatar, isNotNull);
      expect(user.avatar!.thumbnailUrl, isNull);
      expect(user.avatar!.fullUrl, isNull);
      expect(user.avatar!.thumbnailSizeBytes, 24000);
      expect(user.avatar!.fullSizeBytes, 180000);
      expect(user.effectiveAvatarThumbnailUrl, isNull);
      expect(user.effectiveAvatarFullUrl, isNull);
      expect(user.hasAvatar, isTrue);
    });

    test('uses legacy avatarUrl when new metadata is absent', () {
      final user = AppUser.fromMap({
        'uid': 'legacy-user',
        'email': 'legacy@example.com',
        'name': 'Старый пользователь',
        'phone': '',
        'about': '',
        'avatarUrl': 'https://example.com/legacy.jpg',
      });

      expect(user.avatar, isNull);
      expect(
        user.effectiveAvatarThumbnailUrl,
        'https://example.com/legacy.jpg',
      );
      expect(user.effectiveAvatarFullUrl, 'https://example.com/legacy.jpg');
      expect(user.hasAvatar, isTrue);
    });

    test('serializes exactly the established avatar metadata fields', () {
      final updatedAt = DateTime.utc(2026, 7, 26, 13, 45);

      final avatar = UserAvatar(
        thumbnail: MediaAsset(
          id: 'thumb',
          provider: 'firebase',
          path: 'user_avatars/user-1/v12/thumb.jpg',
          type: 'userAvatarThumbnail',
          ownerType: 'user',
          ownerId: 'user-1',
          mimeType: 'image/jpeg',
          sizeBytes: 24000,
          version: 12,
          updatedAt: updatedAt,
        ),
        full: MediaAsset(
          id: 'full',
          provider: 'firebase',
          path: 'user_avatars/user-1/v12/full.jpg',
          type: 'userAvatarFull',
          ownerType: 'user',
          ownerId: 'user-1',
          mimeType: 'image/jpeg',
          sizeBytes: 180000,
          version: 12,
          updatedAt: updatedAt,
        ),
      );

      expect(AppUser.avatarMetadataToMap(avatar), {
        'avatarProvider': 'firebase',
        'avatarThumbStoragePath': 'user_avatars/user-1/v12/thumb.jpg',
        'avatarFullStoragePath': 'user_avatars/user-1/v12/full.jpg',
        'avatarThumbSizeBytes': 24000,
        'avatarFullSizeBytes': 180000,
        'avatarVersion': 12,
        'avatarUpdatedAt': updatedAt,
      });
    });

    test('toMap keeps legacy URLs without writing path-first metadata', () {
      final user = AppUser.fromMap({
        'uid': 'legacy-user',
        'email': 'legacy@example.com',
        'name': 'Legacy User',
        'phone': '+10000000000',
        'about': 'Legacy profile',
        'avatarUrl': 'https://example.com/legacy.jpg',
        'avatarProvider': 'firebase',
        'avatarThumbUrl': 'https://example.com/thumb.jpg',
        'avatarFullUrl': 'https://example.com/full.jpg',
        'avatarThumbStoragePath': 'user_avatars/legacy-user/v2/thumb.jpg',
        'avatarFullStoragePath': 'user_avatars/legacy-user/v2/full.jpg',
        'avatarVersion': 2,
        'avatarUpdatedAt': DateTime.utc(2026, 7, 25),
      });

      final serialized = user.toMap();

      expect(serialized['avatarUrl'], 'https://example.com/legacy.jpg');

      for (final field in const <String>[
        'avatarProvider',
        'avatarThumbStoragePath',
        'avatarFullStoragePath',
        'avatarThumbSizeBytes',
        'avatarFullSizeBytes',
        'avatarVersion',
        'avatarUpdatedAt',
      ]) {
        expect(serialized.containsKey(field), isFalse, reason: field);
      }

      expect(AppUser.fromMap(serialized).avatarUrl, user.avatarUrl);
    });

    test('toMap round-trips complete path-first metadata', () {
      final updatedAt = DateTime.utc(2026, 7, 26, 14);

      final user = AppUser.fromMap({
        'uid': 'user-1',
        'email': 'user@example.com',
        'name': 'Path First',
        'phone': '',
        'about': '',
        'avatarUrl': '',
        'avatarProvider': 'firebase',
        'avatarThumbStoragePath': 'user_avatars/user-1/v5/thumb.jpg',
        'avatarFullStoragePath': 'user_avatars/user-1/v5/full.jpg',
        'avatarThumbSizeBytes': 24000,
        'avatarFullSizeBytes': 180000,
        'avatarVersion': 5,
        'avatarUpdatedAt': updatedAt,
      });

      final serialized = user.toMap();
      final roundTripped = AppUser.fromMap(serialized);

      expect(
        serialized,
        containsPair('avatarThumbStoragePath', user.avatar!.thumbnail.path),
      );
      expect(serialized, containsPair('avatarVersion', 5));
      expect(serialized.containsKey('avatarThumbUrl'), isFalse);
      expect(serialized.containsKey('avatarFullUrl'), isFalse);
      expect(roundTripped.avatar?.hasPersistableMetadata, isTrue);
      expect(roundTripped.avatar?.thumbnailSizeBytes, 24000);
      expect(roundTripped.avatar?.fullSizeBytes, 180000);
      expect(roundTripped.avatar?.updatedAt, updatedAt);
    });

    test('toMap round-trips a user without an avatar', () {
      final user = AppUser.fromMap({
        'uid': 'user-without-avatar',
        'email': 'none@example.com',
        'name': 'No Avatar',
        'phone': '',
        'about': '',
      });

      final serialized = user.toMap();
      final roundTripped = AppUser.fromMap(serialized);

      expect(serialized.keys, {
        'uid',
        'email',
        'name',
        'workDisplayName',
        'phone',
        'about',
        'avatarUrl',
        'createdAt',
      });
      expect(roundTripped.avatar, isNull);
      expect(roundTripped.avatarUrl, isEmpty);
      expect(roundTripped.hasAvatar, isFalse);
    });

    test('rejects incomplete new metadata', () {
      final user = AppUser.fromMap({
        'uid': 'user-2',
        'email': 'user2@example.com',
        'name': 'Пользователь',
        'phone': '',
        'about': '',
        'avatarProvider': 'firebase',
        'avatarThumbUrl': 'https://example.com/thumb.jpg',
        'avatarFullUrl': '',
        'avatarThumbStoragePath': 'user_avatars/user-2/v4/thumb.jpg',
        'avatarFullStoragePath': 'user_avatars/user-2/v4/full.jpg',
        'avatarVersion': 4,
      });

      expect(user.avatar, isNull);
      expect(user.hasAvatar, isFalse);
    });

    test('uses safe defaults for an empty map', () {
      final user = AppUser.fromMap(const {});

      expect(user.uid, isEmpty);
      expect(user.email, isEmpty);
      expect(user.name, isEmpty);
      expect(user.workDisplayName, isEmpty);
      expect(user.effectiveWorkDisplayName, isEmpty);
      expect(user.avatarUrl, isEmpty);
      expect(user.avatar, isNull);
      expect(user.hasAvatar, isFalse);
    });
  });

  group('AppUser work display name', () {
    test('uses workDisplayName in spaces when it is present', () {
      final user = AppUser.fromMap(const {
        'uid': 'user-1',
        'email': 'ivan@example.com',
        'name': 'Vanya',
        'workDisplayName': 'Иванов Иван Иванович',
        'phone': '',
        'about': '',
      });

      expect(user.name, 'Vanya');
      expect(user.workDisplayName, 'Иванов Иван Иванович');
      expect(user.effectiveWorkDisplayName, 'Иванов Иван Иванович');
    });

    test('falls back to regular name for existing users', () {
      final user = AppUser.fromMap(const {
        'uid': 'user-1',
        'email': 'ivan@example.com',
        'name': 'Vanya',
        'phone': '',
        'about': '',
      });

      expect(user.workDisplayName, isEmpty);
      expect(user.effectiveWorkDisplayName, 'Vanya');
    });

    test('falls back when workDisplayName contains only whitespace', () {
      final user = AppUser.fromMap(const {
        'uid': 'user-1',
        'email': 'ivan@example.com',
        'name': 'Иван Иванов',
        'workDisplayName': '   ',
        'phone': '',
        'about': '',
      });

      expect(user.workDisplayName, isEmpty);
      expect(user.effectiveWorkDisplayName, 'Иван Иванов');
    });

    test('toMap persists workDisplayName', () {
      const user = AppUser(
        uid: 'user-1',
        email: 'ivan@example.com',
        name: 'Vanya',
        workDisplayName: 'Иванов Иван Иванович',
        phone: '',
        about: '',
      );

      final data = user.toMap();

      expect(data['name'], 'Vanya');
      expect(data['workDisplayName'], 'Иванов Иван Иванович');
    });
  });
}
