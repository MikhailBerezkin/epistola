import 'package:epistola/helpers/role_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoleHelper.title', () {
    test('returns expected titles for supported roles', () {
      expect(RoleHelper.title('owner'), 'Владелец');
      expect(RoleHelper.title('admin'), 'Администратор');
      expect(RoleHelper.title('moderator'), 'Модератор');
      expect(RoleHelper.title('member'), 'Участник');
      expect(RoleHelper.title('guest'), 'Гость');
    });

    test('falls back to member title for an unknown role', () {
      expect(RoleHelper.title('unknown'), 'Участник');
    });
  });

  group('RoleHelper permissions', () {
    test('recognizes admin and owner', () {
      expect(RoleHelper.isAdminOrOwner('owner'), isTrue);
      expect(RoleHelper.isAdminOrOwner('admin'), isTrue);

      expect(RoleHelper.isAdminOrOwner('moderator'), isFalse);
      expect(RoleHelper.isAdminOrOwner('member'), isFalse);
      expect(RoleHelper.isAdminOrOwner('guest'), isFalse);
    });

    test('recognizes moderator-or-above hierarchy', () {
      expect(RoleHelper.isModeratorOrAbove('owner'), isTrue);
      expect(RoleHelper.isModeratorOrAbove('admin'), isTrue);
      expect(RoleHelper.isModeratorOrAbove('moderator'), isTrue);

      expect(RoleHelper.isModeratorOrAbove('member'), isFalse);
      expect(RoleHelper.isModeratorOrAbove('guest'), isFalse);
    });
  });
}
