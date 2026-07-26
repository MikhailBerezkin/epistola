import 'package:epistola/widgets/avatar/avatar_initials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarInitials.resolve', () {
    test('uses first and last name initials', () {
      final initials = AvatarInitials.resolve(
        name: 'Иван Сергеевич Петров',
        email: 'ivan@example.com',
      );

      expect(initials, 'ИП');
    });

    test('handles extra whitespace', () {
      final initials = AvatarInitials.resolve(
        name: '  Анна   Смирнова  ',
        email: 'anna@example.com',
      );

      expect(initials, 'АС');
    });

    test('uses one initial for a one-word name', () {
      final initials = AvatarInitials.resolve(
        name: 'Михаил',
        email: 'mikhail@example.com',
      );

      expect(initials, 'М');
    });

    test('falls back to the email initial', () {
      final initials = AvatarInitials.resolve(
        name: '',
        email: 'boriska@example.com',
      );

      expect(initials, 'B');
    });

    test('uses question mark when name and email are empty', () {
      final initials = AvatarInitials.resolve(name: '', email: '');

      expect(initials, '?');
    });
  });

  group('AvatarInitials.stablePaletteIndex', () {
    test('returns the same index for the same user', () {
      final first = AvatarInitials.stablePaletteIndex(
        stableKey: 'user-42',
        paletteLength: 8,
      );

      final second = AvatarInitials.stablePaletteIndex(
        stableKey: 'user-42',
        paletteLength: 8,
      );

      expect(second, first);
    });

    test('returns an index inside the palette', () {
      final index = AvatarInitials.stablePaletteIndex(
        stableKey: 'user-100',
        paletteLength: 8,
      );

      expect(index, inInclusiveRange(0, 7));
    });

    test('rejects an empty palette', () {
      expect(
        () => AvatarInitials.stablePaletteIndex(
          stableKey: 'user-1',
          paletteLength: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
