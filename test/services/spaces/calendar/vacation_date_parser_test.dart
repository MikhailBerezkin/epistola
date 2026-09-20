import 'package:epistola/services/spaces/calendar/vacation_date_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = VacationDateParser();

  group('VacationDateParser.parseDate', () {
    test('parses numeric date with explicit year', () {
      expect(
        parser.parseDate('18.09.2026', defaultYear: 2027),
        DateTime.utc(2026, 9, 18),
      );
    });

    test('parses numeric date with slash without year', () {
      expect(
        parser.parseDate('23/11', defaultYear: 2026),
        DateTime.utc(2026, 11, 23),
      );
    });

    test('parses numeric date with slash and explicit year', () {
      expect(
        parser.parseDate('23/11/2027', defaultYear: 2026),
        DateTime.utc(2027, 11, 23),
      );
    });

    test('uses calendar year for numeric date without year', () {
      expect(
        parser.parseDate('18.09', defaultYear: 2027),
        DateTime.utc(2027, 9, 18),
      );
    });

    test('parses russian month without year', () {
      expect(
        parser.parseDate('18 сентября', defaultYear: 2026),
        DateTime.utc(2026, 9, 18),
      );
    });

    test('parses russian month with explicit year', () {
      expect(
        parser.parseDate('18 сентября 2027', defaultYear: 2026),
        DateTime.utc(2027, 9, 18),
      );
    });

    test('rejects invalid calendar date', () {
      expect(parser.parseDate('30.02.2026', defaultYear: 2026), isNull);
    });

    test('rejects unknown month name', () {
      expect(parser.parseDate('18 неизвестного', defaultYear: 2026), isNull);
    });
  });

  group('VacationDateParser.parseRange', () {
    test('keeps ordinary range inside calendar year', () {
      final range = parser.parseRange(
        startText: '18.09',
        endText: '02.10',
        calendarYear: 2026,
      );

      expect(range, isNotNull);
      expect(range?.startDate, DateTime.utc(2026, 9, 18));
      expect(range?.endDate, DateTime.utc(2026, 10, 2));
    });

    test('parses slash range across new year', () {
      final range = parser.parseRange(
        startText: '20/12',
        endText: '10/01',
        calendarYear: 2026,
      );

      expect(range, isNotNull);
      expect(range?.startDate, DateTime.utc(2026, 12, 20));
      expect(range?.endDate, DateTime.utc(2027, 1, 10));
    });

    test('moves yearless end date into next year when needed', () {
      final range = parser.parseRange(
        startText: '20.12',
        endText: '10.01',
        calendarYear: 2026,
      );

      expect(range, isNotNull);
      expect(range?.startDate, DateTime.utc(2026, 12, 20));
      expect(range?.endDate, DateTime.utc(2027, 1, 10));
    });

    test('uses explicit start year as base for yearless end', () {
      final range = parser.parseRange(
        startText: '20.12.2027',
        endText: '10.01',
        calendarYear: 2026,
      );

      expect(range, isNotNull);
      expect(range?.startDate, DateTime.utc(2027, 12, 20));
      expect(range?.endDate, DateTime.utc(2028, 1, 10));
    });

    test('rejects explicitly reversed range', () {
      final range = parser.parseRange(
        startText: '20.12.2027',
        endText: '10.01.2027',
        calendarYear: 2026,
      );

      expect(range, isNull);
    });
  });
}
