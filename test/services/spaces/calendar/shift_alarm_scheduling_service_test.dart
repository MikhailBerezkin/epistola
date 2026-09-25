import 'package:epistola/domain/models/shift_alarm.dart';
import 'package:epistola/domain/models/shift_alarm_occurrence.dart';
import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/domain/models/vacation_period.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_local_store.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_schedule_planner.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_schedule_reconciler.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_schedule_registry.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_scheduling_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = ShiftAlarmLocalStore();
  const registry = ShiftAlarmScheduleRegistry();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ShiftAlarmSchedulingService', () {
    test('loads local alarms and schedules projected occurrence', () async {
      await store.save(
        userId: 'user-1',
        alarm: _alarm(
          id: 'wake-up',
          phase: ShiftCyclePhase.day1,
          minutesOfDay: 6 * 60,
        ),
      );

      final scheduledOccurrences = <String>[];

      final reconciler = ShiftAlarmScheduleReconciler(
        planner: const ShiftAlarmSchedulePlanner(daysAhead: 2),
        registry: registry,
        schedule:
            ({
              required int notificationId,
              required ShiftAlarmOccurrence occurrence,
            }) async {
              scheduledOccurrences.add(occurrence.occurrenceId);

              return true;
            },
        cancel: ({required int notificationId}) async {},
      );

      final service = ShiftAlarmSchedulingService(
        store: store,
        reconciler: reconciler,
      );

      final result = await service.reconcile(
        userId: 'user-1',
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result.desiredCount, 1);
      expect(result.scheduledCount, 1);

      expect(scheduledOccurrences, <String>['wake-up_20260913']);
    });

    test('respects vacation scope through full scheduling chain', () async {
      await store.save(
        userId: 'user-1',
        alarm: _alarm(
          id: 'work',
          scope: ShiftAlarmScope.work,
          minutesOfDay: 6 * 60,
        ),
      );

      await store.save(
        userId: 'user-1',
        alarm: _alarm(
          id: 'always',
          scope: ShiftAlarmScope.always,
          minutesOfDay: 8 * 60,
        ),
      );

      await store.save(
        userId: 'user-1',
        alarm: _alarm(
          id: 'vacation',
          scope: ShiftAlarmScope.vacation,
          minutesOfDay: 9 * 60,
        ),
      );

      final scheduledOccurrences = <String>[];

      final reconciler = ShiftAlarmScheduleReconciler(
        planner: const ShiftAlarmSchedulePlanner(daysAhead: 2),
        registry: registry,
        schedule:
            ({
              required int notificationId,
              required ShiftAlarmOccurrence occurrence,
            }) async {
              scheduledOccurrences.add(occurrence.occurrenceId);

              return true;
            },
        cancel: ({required int notificationId}) async {},
      );

      final service = ShiftAlarmSchedulingService(
        store: store,
        reconciler: reconciler,
      );

      final result = await service.reconcile(
        userId: 'user-1',
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        vacationPeriods: <VacationPeriod>[
          VacationPeriod(
            userId: 'user-1',
            slot: 1,
            startDate: DateTime.utc(2026, 9, 13),
            endDate: DateTime.utc(2026, 9, 13),
          ),
        ],
      );

      expect(result.desiredCount, 2);
      expect(result.scheduledCount, 2);

      expect(scheduledOccurrences, <String>[
        'always_20260913',
        'vacation_20260913',
      ]);
    });

    test('rejects empty user id', () async {
      final reconciler = ShiftAlarmScheduleReconciler(
        registry: registry,
        schedule:
            ({
              required int notificationId,
              required ShiftAlarmOccurrence occurrence,
            }) async {
              return true;
            },
        cancel: ({required int notificationId}) async {},
      );

      final service = ShiftAlarmSchedulingService(
        store: store,
        reconciler: reconciler,
      );

      expect(
        () => service.reconcile(
          userId: '   ',
          crew: ShiftCrew.crew4,
          vacationPeriods: const <VacationPeriod>[],
        ),
        throwsArgumentError,
      );
    });
  });
}

ShiftAlarm _alarm({
  required String id,
  ShiftCyclePhase phase = ShiftCyclePhase.day1,
  ShiftAlarmScope scope = ShiftAlarmScope.work,
  int minutesOfDay = 7 * 60,
}) {
  final timestamp = DateTime.utc(2026, 9, 25, 12);

  return ShiftAlarm(
    id: id,
    phase: phase,
    scope: scope,
    type: ShiftAlarmType.alarm,
    title: 'Тест',
    minutesOfDay: minutesOfDay,
    enabled: true,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
