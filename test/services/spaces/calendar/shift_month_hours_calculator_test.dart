import 'package:flutter_test/flutter_test.dart';

import 'package:epistola/domain/models/calendar_additional_shift_event.dart';
import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/domain/models/vacation_period.dart';
import 'package:epistola/services/spaces/calendar/shift_month_hours_calculator.dart';

void main() {
  group('ShiftMonthHoursCalculator', () {
    const calculator = ShiftMonthHoursCalculator();

    test('full accounted shift is 11.5 hours', () {
      expect(ShiftMonthHoursCalculator.fullShiftMinutes, 690);
    });

    test('night shift is split as 4h + 7.5h', () {
      expect(ShiftMonthHoursCalculator.nightStartMonthMinutes, 240);

      expect(ShiftMonthHoursCalculator.nightNextMonthMinutes, 450);
    });

    test('additional day shift contributes 11.5h', () {
      final summary = calculator.calculate(
        month: DateTime(2026, 9),
        crew: ShiftCrew.crew1,
        vacationPeriods: const <VacationPeriod>[],
        additionalShifts: <CalendarAdditionalShiftEvent>[
          CalendarAdditionalShiftEvent(
            sourceCallId: 'call-day',
            date: DateTime(2026, 9, 15),
            kind: SubstitutionShiftKind.day,
            startAt: DateTime(2026, 9, 15, 8),
            endAt: DateTime(2026, 9, 15, 20),
          ),
        ],
      );

      expect(summary.additionalMinutes, 690);
      expect(summary.additionalHours, 11.5);
    });

    test('additional night shift crossing month contributes 4h then 7.5h', () {
      final event = CalendarAdditionalShiftEvent(
        sourceCallId: 'call-night',
        date: DateTime(2026, 9, 30),
        kind: SubstitutionShiftKind.night,
        startAt: DateTime(2026, 9, 30, 20),
        endAt: DateTime(2026, 10, 1, 8),
      );

      final september = calculator.calculate(
        month: DateTime(2026, 9),
        crew: ShiftCrew.crew1,
        vacationPeriods: const <VacationPeriod>[],
        additionalShifts: <CalendarAdditionalShiftEvent>[event],
      );

      final october = calculator.calculate(
        month: DateTime(2026, 10),
        crew: ShiftCrew.crew1,
        vacationPeriods: const <VacationPeriod>[],
        additionalShifts: <CalendarAdditionalShiftEvent>[event],
      );

      expect(september.additionalMinutes, 240);
      expect(september.additionalHours, 4);

      expect(october.additionalMinutes, 450);
      expect(october.additionalHours, 7.5);
    });

    test('night shift after vacation contributes 7.5h after midnight', () {
      // Для crew3:
      // 15.09.2026 -> Ночь 2
      // 16.09.2026 -> Отсыпной
      //
      // Если отпуск заканчивается 15 сентября,
      // часть 20:00-00:00 ещё относится к отпуску,
      // а 00:00-08:00 16 сентября уже должна дать 7.5 часа.

      final vacationEndsOnNightShift = calculator.calculate(
        month: DateTime(2026, 9),
        crew: ShiftCrew.crew3,
        vacationPeriods: <VacationPeriod>[
          VacationPeriod(
            userId: 'user',
            slot: 1,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 15),
          ),
        ],
        additionalShifts: const <CalendarAdditionalShiftEvent>[],
      );

      final vacationIncludesNextDay = calculator.calculate(
        month: DateTime(2026, 9),
        crew: ShiftCrew.crew3,
        vacationPeriods: <VacationPeriod>[
          VacationPeriod(
            userId: 'user',
            slot: 1,
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 16),
          ),
        ],
        additionalShifts: const <CalendarAdditionalShiftEvent>[],
      );

      expect(
        vacationEndsOnNightShift.regularMinutes -
            vacationIncludesNextDay.regularMinutes,
        ShiftMonthHoursCalculator.nightNextMonthMinutes,
      );
    });

    test('night shift entering vacation keeps first 4h before midnight', () {
      // Для crew3:
      // 15.09.2026 -> Ночь 2
      // 16.09.2026 -> Отсыпной
      //
      // Если отпуск начинается 16 сентября,
      // первые 4 часа ночной смены 15 сентября остаются рабочими,
      // а 7.5 часа после 00:00 уже исключаются отпуском.

      final withoutVacation = calculator.calculate(
        month: DateTime(2026, 9),
        crew: ShiftCrew.crew3,
        vacationPeriods: const <VacationPeriod>[],
        additionalShifts: const <CalendarAdditionalShiftEvent>[],
      );

      final vacationStartsAfterMidnight = calculator.calculate(
        month: DateTime(2026, 9),
        crew: ShiftCrew.crew3,
        vacationPeriods: <VacationPeriod>[
          VacationPeriod(
            userId: 'user',
            slot: 1,
            startDate: DateTime(2026, 9, 16),
            endDate: DateTime(2026, 9, 16),
          ),
        ],
        additionalShifts: const <CalendarAdditionalShiftEvent>[],
      );

      expect(
        withoutVacation.regularMinutes -
            vacationStartsAfterMidnight.regularMinutes,
        ShiftMonthHoursCalculator.nightNextMonthMinutes,
      );
    });

    test('total is regular plus additional', () {
      final summary = calculator.calculate(
        month: DateTime(2026, 9),
        crew: ShiftCrew.crew1,
        vacationPeriods: const <VacationPeriod>[],
        additionalShifts: <CalendarAdditionalShiftEvent>[
          CalendarAdditionalShiftEvent(
            sourceCallId: 'call-day',
            date: DateTime(2026, 9, 15),
            kind: SubstitutionShiftKind.day,
            startAt: DateTime(2026, 9, 15, 8),
            endAt: DateTime(2026, 9, 15, 20),
          ),
        ],
      );

      expect(
        summary.totalMinutes,
        summary.regularMinutes + summary.additionalMinutes,
      );
    });
  });
}
