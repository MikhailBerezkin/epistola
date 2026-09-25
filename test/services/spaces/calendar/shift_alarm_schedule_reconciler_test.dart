import 'package:epistola/domain/models/shift_alarm.dart';
import 'package:epistola/domain/models/shift_alarm_occurrence.dart';
import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/domain/models/vacation_period.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_schedule_planner.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_schedule_reconciler.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_schedule_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const registry = ShiftAlarmScheduleRegistry();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ShiftAlarmScheduleReconciler', () {
    test('creates stable notification id from occurrence id', () {
      final first = ShiftAlarmScheduleReconciler.notificationIdForOccurrenceId(
        'wake-up_20260913',
      );

      final second = ShiftAlarmScheduleReconciler.notificationIdForOccurrenceId(
        'wake-up_20260913',
      );

      final other = ShiftAlarmScheduleReconciler.notificationIdForOccurrenceId(
        'wake-up_20260921',
      );

      expect(first, second);
      expect(first, isNot(other));

      expect(first, inInclusiveRange(0, 0x7fffffff));
    });

    test('rejects empty occurrence id', () {
      expect(
        () => ShiftAlarmScheduleReconciler.notificationIdForOccurrenceId('   '),
        throwsArgumentError,
      );
    });

    test('schedules desired occurrences and stores registry', () async {
      final scheduledIds = <int>[];
      final scheduledOccurrences = <String>[];

      final reconciler = ShiftAlarmScheduleReconciler(
        planner: const ShiftAlarmSchedulePlanner(daysAhead: 2),
        registry: registry,
        schedule:
            ({
              required int notificationId,
              required ShiftAlarmOccurrence occurrence,
            }) async {
              scheduledIds.add(notificationId);
              scheduledOccurrences.add(occurrence.occurrenceId);

              return true;
            },
        cancel: ({required int notificationId}) async {},
      );

      final result = await reconciler.reconcile(
        userId: 'user-1',
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[
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

      expect(result.desiredCount, 2);
      expect(result.scheduledCount, 2);
      expect(result.cancelledCount, 0);

      expect(scheduledOccurrences, <String>[
        'wake-up_20260913',
        'lunch_20260913',
      ]);

      final stored = await registry.loadForUser(userId: 'user-1');

      expect(stored, hasLength(2));

      expect(stored.map((item) => item.notificationId), scheduledIds);
    });

    test('cancels previous registry before rebuilding schedule', () async {
      final previousId =
          ShiftAlarmScheduleReconciler.notificationIdForOccurrenceId(
            'old_20260913',
          );

      await registry.replaceForUser(
        userId: 'user-1',
        items: <ShiftAlarmScheduledItem>[
          ShiftAlarmScheduledItem(
            occurrenceId: 'old_20260913',
            notificationId: previousId,
          ),
        ],
      );

      final actions = <String>[];

      final reconciler = ShiftAlarmScheduleReconciler(
        planner: const ShiftAlarmSchedulePlanner(daysAhead: 2),
        registry: registry,
        schedule:
            ({
              required int notificationId,
              required ShiftAlarmOccurrence occurrence,
            }) async {
              actions.add('schedule:${occurrence.occurrenceId}');

              return true;
            },
        cancel: ({required int notificationId}) async {
          actions.add('cancel:$notificationId');
        },
      );

      await reconciler.reconcile(
        userId: 'user-1',
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[_alarm(id: 'new', minutesOfDay: 6 * 60)],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(actions, <String>['cancel:$previousId', 'schedule:new_20260913']);
    });

    test('reschedules existing occurrence to apply edits', () async {
      final occurrenceId = 'wake-up_20260913';

      final notificationId =
          ShiftAlarmScheduleReconciler.notificationIdForOccurrenceId(
            occurrenceId,
          );

      await registry.replaceForUser(
        userId: 'user-1',
        items: <ShiftAlarmScheduledItem>[
          ShiftAlarmScheduledItem(
            occurrenceId: occurrenceId,
            notificationId: notificationId,
          ),
        ],
      );

      final cancelledIds = <int>[];
      final scheduledTimes = <DateTime>[];

      final reconciler = ShiftAlarmScheduleReconciler(
        planner: const ShiftAlarmSchedulePlanner(daysAhead: 2),
        registry: registry,
        schedule:
            ({
              required int notificationId,
              required ShiftAlarmOccurrence occurrence,
            }) async {
              scheduledTimes.add(occurrence.scheduledAt);

              return true;
            },
        cancel: ({required int notificationId}) async {
          cancelledIds.add(notificationId);
        },
      );

      await reconciler.reconcile(
        userId: 'user-1',
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[_alarm(id: 'wake-up', minutesOfDay: 6 * 60 + 15)],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(cancelledIds, <int>[notificationId]);

      expect(scheduledTimes, <DateTime>[DateTime(2026, 9, 13, 6, 15)]);
    });

    test('does not store occurrence when native scheduling fails', () async {
      final reconciler = ShiftAlarmScheduleReconciler(
        planner: const ShiftAlarmSchedulePlanner(daysAhead: 2),
        registry: registry,
        schedule:
            ({
              required int notificationId,
              required ShiftAlarmOccurrence occurrence,
            }) async {
              return false;
            },
        cancel: ({required int notificationId}) async {},
      );

      final result = await reconciler.reconcile(
        userId: 'user-1',
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[_alarm(id: 'wake-up', minutesOfDay: 6 * 60)],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result.desiredCount, 1);
      expect(result.scheduledCount, 0);

      final stored = await registry.loadForUser(userId: 'user-1');

      expect(stored, isEmpty);
    });

    test('clears previous schedule when nothing is desired', () async {
      await registry.replaceForUser(
        userId: 'user-1',
        items: const <ShiftAlarmScheduledItem>[
          ShiftAlarmScheduledItem(occurrenceId: 'old', notificationId: 123),
        ],
      );

      final cancelledIds = <int>[];

      final reconciler = ShiftAlarmScheduleReconciler(
        planner: const ShiftAlarmSchedulePlanner(daysAhead: 1),
        registry: registry,
        schedule:
            ({
              required int notificationId,
              required ShiftAlarmOccurrence occurrence,
            }) async {
              return true;
            },
        cancel: ({required int notificationId}) async {
          cancelledIds.add(notificationId);
        },
      );

      final result = await reconciler.reconcile(
        userId: 'user-1',
        now: DateTime(2026, 9, 12, 12),
        crew: ShiftCrew.crew4,
        alarms: <ShiftAlarm>[_alarm(id: 'day-1', phase: ShiftCyclePhase.day1)],
        vacationPeriods: const <VacationPeriod>[],
      );

      expect(result.desiredCount, 0);
      expect(result.scheduledCount, 0);
      expect(result.cancelledCount, 1);

      expect(cancelledIds, <int>[123]);

      final stored = await registry.loadForUser(userId: 'user-1');

      expect(stored, isEmpty);
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
