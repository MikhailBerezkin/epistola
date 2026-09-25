import 'package:epistola/domain/models/shift_alarm.dart';
import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/domain/models/vacation_period.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_occurrence_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ShiftAlarmOccurrenceResolver();

  group('ShiftAlarmOccurrenceResolver', () {
    test('returns work and always alarms outside vacation', () {
      final alarms = <ShiftAlarm>[
        _alarm(
          id: 'work',
          scope: ShiftAlarmScope.work,
          title: 'Подъём',
          minutesOfDay: 6 * 60,
        ),
        _alarm(
          id: 'always',
          scope: ShiftAlarmScope.always,
          title: 'Лекарство',
          minutesOfDay: 8 * 60,
        ),
        _alarm(
          id: 'vacation',
          scope: ShiftAlarmScope.vacation,
          title: 'Отпуск',
          minutesOfDay: 9 * 60,
        ),
      ];

      final result = resolver.alarmsForDate(
        date: DateTime(2026, 9, 13),
        crew: ShiftCrew.crew4,
        alarms: alarms,
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result.map((alarm) => alarm.id), <String>['work', 'always']);
    });

    test('returns always and vacation alarms during vacation', () {
      final alarms = <ShiftAlarm>[
        _alarm(
          id: 'work',
          scope: ShiftAlarmScope.work,
          title: 'Подъём',
          minutesOfDay: 6 * 60,
        ),
        _alarm(
          id: 'always',
          scope: ShiftAlarmScope.always,
          title: 'Лекарство',
          minutesOfDay: 8 * 60,
        ),
        _alarm(
          id: 'vacation',
          scope: ShiftAlarmScope.vacation,
          title: 'Отпуск',
          minutesOfDay: 9 * 60,
        ),
      ];

      final result = resolver.alarmsForDate(
        date: DateTime(2026, 9, 13),
        crew: ShiftCrew.crew4,
        alarms: alarms,
        vacationPeriods: <VacationPeriod>[
          VacationPeriod(
            userId: 'user-1',
            slot: 1,
            startDate: DateTime.utc(2026, 9, 10),
            endDate: DateTime.utc(2026, 9, 20),
          ),
        ],
      );

      expect(result.map((alarm) => alarm.id), <String>['always', 'vacation']);
    });

    test('ignores alarms from another cycle phase', () {
      final result = resolver.alarmsForDate(
        date: DateTime(2026, 9, 13),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[
          _alarm(id: 'day-1', phase: ShiftCyclePhase.day1),
          _alarm(id: 'day-2', phase: ShiftCyclePhase.day2),
        ],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result.map((alarm) => alarm.id), <String>['day-1']);
    });

    test('ignores disabled alarms', () {
      final result = resolver.alarmsForDate(
        date: DateTime(2026, 9, 13),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[
          _alarm(id: 'enabled', enabled: true),
          _alarm(id: 'disabled', enabled: false),
        ],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result.map((alarm) => alarm.id), <String>['enabled']);
    });

    test('sorts alarms by time', () {
      final result = resolver.alarmsForDate(
        date: DateTime(2026, 9, 13),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[
          _alarm(id: 'third', minutesOfDay: 19 * 60 + 20),
          _alarm(id: 'first', minutesOfDay: 6 * 60),
          _alarm(id: 'second', minutesOfDay: 13 * 60 + 10),
        ],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result.map((alarm) => alarm.id), <String>[
        'first',
        'second',
        'third',
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
  bool enabled = true,
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
    enabled: enabled,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
