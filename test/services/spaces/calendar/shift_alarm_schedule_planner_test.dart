import 'package:epistola/domain/models/shift_alarm.dart';
import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/domain/models/vacation_period.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_schedule_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShiftAlarmSchedulePlanner', () {
    test('projects repeated alarm through 8-day cycle', () {
      const planner = ShiftAlarmSchedulePlanner(daysAhead: 17);

      final result = planner.plan(
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[
          _alarm(
            id: 'wake-up',
            phase: ShiftCyclePhase.day1,
            minutesOfDay: 6 * 60,
          ),
        ],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result.map((item) => item.scheduledAt), <DateTime>[
        DateTime(2026, 9, 13, 6),
        DateTime(2026, 9, 21, 6),
      ]);
    });

    test('skips occurrence earlier today', () {
      const planner = ShiftAlarmSchedulePlanner(daysAhead: 2);

      final result = planner.plan(
        now: DateTime(2026, 9, 13, 7),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[
          _alarm(id: 'early', minutesOfDay: 6 * 60),
          _alarm(id: 'later', minutesOfDay: 19 * 60 + 20),
        ],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result, hasLength(1));
      expect(result.single.alarm.id, 'later');
      expect(result.single.scheduledAt, DateTime(2026, 9, 13, 19, 20));
    });

    test('suppresses work alarms during vacation', () {
      const planner = ShiftAlarmSchedulePlanner(daysAhead: 2);

      final result = planner.plan(
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[
          _alarm(id: 'work', scope: ShiftAlarmScope.work, minutesOfDay: 6 * 60),
          _alarm(
            id: 'always',
            scope: ShiftAlarmScope.always,
            minutesOfDay: 8 * 60,
          ),
          _alarm(
            id: 'vacation',
            scope: ShiftAlarmScope.vacation,
            minutesOfDay: 9 * 60,
          ),
        ],
        vacationPeriods: <VacationPeriod>[
          VacationPeriod(
            userId: 'user-1',
            slot: 1,
            startDate: DateTime.utc(2026, 9, 13),
            endDate: DateTime.utc(2026, 9, 13),
          ),
        ],
      );

      expect(result.map((item) => item.alarm.id), <String>[
        'always',
        'vacation',
      ]);
    });

    test('keeps unique occurrence id for every cycle date', () {
      const planner = ShiftAlarmSchedulePlanner(daysAhead: 17);

      final result = planner.plan(
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[_alarm(id: 'wake-up', minutesOfDay: 6 * 60)],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result, hasLength(2));
      expect(result[0].occurrenceId, 'wake-up_20260913');
      expect(result[1].occurrenceId, 'wake-up_20260921');
    });

    test('sorts different alarms chronologically', () {
      const planner = ShiftAlarmSchedulePlanner(daysAhead: 2);

      final result = planner.plan(
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[
          _alarm(id: 'home', minutesOfDay: 19 * 60 + 20),
          _alarm(id: 'wake-up', minutesOfDay: 6 * 60),
          _alarm(
            id: 'lunch',
            type: ShiftAlarmType.notification,
            minutesOfDay: 13 * 60 + 10,
            durationSeconds: 15,
          ),
        ],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result.map((item) => item.alarm.id), <String>[
        'wake-up',
        'lunch',
        'home',
      ]);
    });
  });
}

ShiftAlarm _alarm({
  required String id,
  ShiftCyclePhase phase = ShiftCyclePhase.day1,
  ShiftAlarmScope scope = ShiftAlarmScope.work,
  ShiftAlarmType type = ShiftAlarmType.alarm,
  String title = 'Сигнал',
  int minutesOfDay = 7 * 60,
  int? durationSeconds,
}) {
  final timestamp = DateTime.utc(2026, 9, 25, 12);

  return ShiftAlarm(
    id: id,
    phase: phase,
    scope: scope,
    type: type,
    title: title,
    minutesOfDay: minutesOfDay,
    durationSeconds: durationSeconds,
    enabled: true,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
