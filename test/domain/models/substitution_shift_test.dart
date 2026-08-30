import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubstitutionShift', () {
    test('day shift runs from 08 to 20 on same calendar day', () {
      final shift = SubstitutionShift(
        year: 2026,
        month: 8,
        day: 31,
        kind: SubstitutionShiftKind.day,
      );

      expect(shift.startHour, 8);
      expect(shift.endHour, 20);
      expect(shift.endsOnNextCalendarDay, false);

      expect(shift.statisticsYear, 2026);
      expect(shift.statisticsMonth, 8);
    });

    test('night shift belongs entirely to month of its start date', () {
      final shift = SubstitutionShift(
        year: 2026,
        month: 8,
        day: 31,
        kind: SubstitutionShiftKind.night,
      );

      expect(shift.startHour, 20);
      expect(shift.endHour, 8);
      expect(shift.endsOnNextCalendarDay, true);

      // Смена идёт:
      // 31.08 20:00 -> 01.09 08:00
      //
      // Но статистика целиком относится к августу.
      expect(shift.statisticsYear, 2026);
      expect(shift.statisticsMonth, 8);
    });

    test('night shift on December 31 belongs to previous year', () {
      final shift = SubstitutionShift(
        year: 2026,
        month: 12,
        day: 31,
        kind: SubstitutionShiftKind.night,
      );

      // Смена закончится 01.01.2027,
      // но является сменой 31.12.2026.
      expect(shift.statisticsYear, 2026);
      expect(shift.statisticsMonth, 12);
    });

    test('day shift on September 1 belongs to September', () {
      final shift = SubstitutionShift(
        year: 2026,
        month: 9,
        day: 1,
        kind: SubstitutionShiftKind.day,
      );

      expect(shift.statisticsYear, 2026);
      expect(shift.statisticsMonth, 9);
    });

    test('accepts leap year February 29', () {
      final shift = SubstitutionShift(
        year: 2028,
        month: 2,
        day: 29,
        kind: SubstitutionShiftKind.day,
      );

      expect(shift.calendarDateUtc, DateTime.utc(2028, 2, 29));
    });

    test('rejects impossible calendar date', () {
      expect(
        () => SubstitutionShift(
          year: 2026,
          month: 2,
          day: 29,
          kind: SubstitutionShiftKind.day,
        ),
        throwsArgumentError,
      );

      expect(
        () => SubstitutionShift(
          year: 2026,
          month: 4,
          day: 31,
          kind: SubstitutionShiftKind.night,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid month', () {
      expect(
        () => SubstitutionShift(
          year: 2026,
          month: 13,
          day: 1,
          kind: SubstitutionShiftKind.day,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid year', () {
      expect(
        () => SubstitutionShift(
          year: 0,
          month: 1,
          day: 1,
          kind: SubstitutionShiftKind.day,
        ),
        throwsArgumentError,
      );
    });
  });
}
