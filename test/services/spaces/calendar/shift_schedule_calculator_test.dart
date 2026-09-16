import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/services/spaces/calendar/shift_schedule_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = ShiftScheduleCalculator();

  group('ShiftScheduleCalculator - 4 звено', () {
    test('matches verified September 2026 cycle', () {
      final expected = <DateTime, ShiftCyclePhase>{
        DateTime(2026, 9, 12): ShiftCyclePhase.offAfterRecovery2,
        DateTime(2026, 9, 13): ShiftCyclePhase.day1,
        DateTime(2026, 9, 14): ShiftCyclePhase.day2,
        DateTime(2026, 9, 15): ShiftCyclePhase.offBeforeNight,
        DateTime(2026, 9, 16): ShiftCyclePhase.night1,
        DateTime(2026, 9, 17): ShiftCyclePhase.night2,
        DateTime(2026, 9, 18): ShiftCyclePhase.recovery,
        DateTime(2026, 9, 19): ShiftCyclePhase.offAfterRecovery1,
        DateTime(2026, 9, 20): ShiftCyclePhase.offAfterRecovery2,
        DateTime(2026, 9, 21): ShiftCyclePhase.day1,
      };

      for (final entry in expected.entries) {
        expect(
          calculator.phaseFor(date: entry.key, crew: ShiftCrew.crew4),
          entry.value,
          reason: 'Unexpected phase for ${entry.key}',
        );
      }
    });

    test('repeats after eight days', () {
      final first = calculator.phaseFor(
        date: DateTime(2026, 9, 13),
        crew: ShiftCrew.crew4,
      );

      final repeated = calculator.phaseFor(
        date: DateTime(2026, 9, 21),
        crew: ShiftCrew.crew4,
      );

      expect(first, ShiftCyclePhase.day1);
      expect(repeated, first);
    });

    test('ignores time of day', () {
      final morning = calculator.phaseFor(
        date: DateTime(2026, 9, 14, 0, 1),
        crew: ShiftCrew.crew4,
      );

      final evening = calculator.phaseFor(
        date: DateTime(2026, 9, 14, 23, 59),
        crew: ShiftCrew.crew4,
      );

      expect(morning, ShiftCyclePhase.day2);
      expect(evening, ShiftCyclePhase.day2);
    });
  });

  group('ShiftScheduleCalculator - crew anchors', () {
    test('matches known phases on 14 September 2026', () {
      final date = DateTime(2026, 9, 14);

      expect(
        calculator.phaseFor(date: date, crew: ShiftCrew.crew1),
        ShiftCyclePhase.offAfterRecovery2,
      );

      expect(
        calculator.phaseFor(date: date, crew: ShiftCrew.crew2),
        ShiftCyclePhase.recovery,
      );

      expect(
        calculator.phaseFor(date: date, crew: ShiftCrew.crew3),
        ShiftCyclePhase.night1,
      );

      expect(
        calculator.phaseFor(date: date, crew: ShiftCrew.crew4),
        ShiftCyclePhase.day2,
      );
    });

    test('crew 1 starts first day shift on 15 September 2026', () {
      expect(
        calculator.phaseFor(date: DateTime(2026, 9, 15), crew: ShiftCrew.crew1),
        ShiftCyclePhase.day1,
      );
    });

    test('crew 3 has second night on 15 September 2026', () {
      expect(
        calculator.phaseFor(date: DateTime(2026, 9, 15), crew: ShiftCrew.crew3),
        ShiftCyclePhase.night2,
      );
    });

    test('crew 4 has night shifts on 16 and 17 September 2026', () {
      expect(
        calculator.phaseFor(date: DateTime(2026, 9, 16), crew: ShiftCrew.crew4),
        ShiftCyclePhase.night1,
      );

      expect(
        calculator.phaseFor(date: DateTime(2026, 9, 17), crew: ShiftCrew.crew4),
        ShiftCyclePhase.night2,
      );
    });
  });

  group('ShiftCyclePhase', () {
    test('contains exactly eight positions', () {
      expect(ShiftCyclePhase.values, hasLength(8));
    });

    test('keeps three off positions separate internally', () {
      expect(ShiftCyclePhase.offBeforeNight.displayLabel, 'Вых');
      expect(ShiftCyclePhase.offAfterRecovery1.displayLabel, 'Вых');
      expect(ShiftCyclePhase.offAfterRecovery2.displayLabel, 'Вых');

      expect(
        ShiftCyclePhase.offBeforeNight,
        isNot(ShiftCyclePhase.offAfterRecovery1),
      );
      expect(
        ShiftCyclePhase.offAfterRecovery1,
        isNot(ShiftCyclePhase.offAfterRecovery2),
      );
    });
  });
}
