import 'package:epistola/helpers/chat_date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatDateFormatter', () {
    final now = DateTime(2026, 8, 3, 15, 30);

    test('formats the current day as Сегодня', () {
      final result = ChatDateFormatter.format(
        DateTime(2026, 8, 3, 8, 10),
        now: now,
      );

      expect(result, 'Сегодня');
    });

    test('formats the previous day as Вчера', () {
      final result = ChatDateFormatter.format(
        DateTime(2026, 8, 2, 23, 59),
        now: now,
      );

      expect(result, 'Вчера');
    });

    test('handles yesterday across a month boundary', () {
      final result = ChatDateFormatter.format(
        DateTime(2026, 7, 31, 12),
        now: DateTime(2026, 8, 1, 9),
      );

      expect(result, 'Вчера');
    });

    test('handles yesterday across a year boundary', () {
      final result = ChatDateFormatter.format(
        DateTime(2025, 12, 31, 22),
        now: DateTime(2026, 1, 1, 9),
      );

      expect(result, 'Вчера');
    });

    test('omits the year for another date in the current year', () {
      final result = ChatDateFormatter.format(
        DateTime(2026, 5, 14, 11),
        now: now,
      );

      expect(result, '14 мая');
    });

    test('includes the year for a date from another year', () {
      final result = ChatDateFormatter.format(
        DateTime(2025, 12, 28, 11),
        now: now,
      );

      expect(result, '28 декабря 2025');
    });

    test('compares calendar days without comparing time', () {
      final result = ChatDateFormatter.isSameDay(
        DateTime(2026, 8, 3, 0, 1),
        DateTime(2026, 8, 3, 23, 59),
      );

      expect(result, isTrue);
    });

    test('detects the first message as the start of a day', () {
      final result = ChatDateFormatter.startsNewDay(
        current: DateTime(2026, 8, 3, 10),
      );

      expect(result, isTrue);
    });

    test('detects a transition between calendar days', () {
      final result = ChatDateFormatter.startsNewDay(
        current: DateTime(2026, 8, 3, 0, 1),
        previous: DateTime(2026, 8, 2, 23, 59),
      );

      expect(result, isTrue);
    });

    test('does not split messages from the same calendar day', () {
      final result = ChatDateFormatter.startsNewDay(
        current: DateTime(2026, 8, 3, 18),
        previous: DateTime(2026, 8, 3, 8),
      );

      expect(result, isFalse);
    });
  });
}
