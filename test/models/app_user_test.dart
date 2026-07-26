import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUser avatars', () {
    test('reads complete avatar metadata from the user document', () {
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
      expect(user.avatarUrl, isEmpty);
      expect(user.avatar, isNull);
      expect(user.hasAvatar, isFalse);
    });
  });
}
