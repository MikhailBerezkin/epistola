import 'package:epistola/services/media/media_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaPaths user avatars', () {
    test('builds versioned thumbnail path', () {
      final path = MediaPaths.userAvatarThumbnail(userId: 'user-1', version: 3);

      expect(path, 'user_avatars/user-1/v3/thumb.jpg');
    });

    test('builds versioned full image path', () {
      final path = MediaPaths.userAvatarFull(userId: 'user-1', version: 3);

      expect(path, 'user_avatars/user-1/v3/full.jpg');
    });

    test('keeps thumbnail and full image in the same version folder', () {
      final thumbnail = MediaPaths.userAvatarThumbnail(
        userId: 'user-42',
        version: 1785064212345678,
      );

      final full = MediaPaths.userAvatarFull(
        userId: 'user-42',
        version: 1785064212345678,
      );

      expect(thumbnail, 'user_avatars/user-42/v1785064212345678/thumb.jpg');
      expect(full, 'user_avatars/user-42/v1785064212345678/full.jpg');
    });
  });

  group('MediaPaths legacy compatibility', () {
    test('keeps the previous user avatar path temporarily', () {
      expect(MediaPaths.userAvatar('user-1'), 'user_avatars/user-1/avatar.jpg');
    });

    test('keeps the existing group avatar path unchanged', () {
      expect(
        MediaPaths.groupAvatar('group-1'),
        'group_avatars/group-1/avatar.jpg',
      );
    });
  });
}
