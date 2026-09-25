import '../../../domain/models/shift_alarm.dart';
import '../../../domain/models/shift_alarm_occurrence.dart';
import '../../../domain/models/shift_cycle.dart';
import '../../../domain/models/vacation_period.dart';
import 'shift_alarm_schedule_planner.dart';
import 'shift_alarm_schedule_registry.dart';

typedef ShiftAlarmOccurrenceSchedule =
    Future<bool> Function({
      required int notificationId,
      required ShiftAlarmOccurrence occurrence,
    });

typedef ShiftAlarmOccurrenceCancel =
    Future<void> Function({required int notificationId});

final class ShiftAlarmReconcileResult {
  const ShiftAlarmReconcileResult({
    required this.desiredCount,
    required this.scheduledCount,
    required this.cancelledCount,
  });

  final int desiredCount;
  final int scheduledCount;
  final int cancelledCount;
}

final class ShiftAlarmScheduleReconciler {
  factory ShiftAlarmScheduleReconciler({
    ShiftAlarmSchedulePlanner planner = const ShiftAlarmSchedulePlanner(),
    ShiftAlarmScheduleRegistry registry = const ShiftAlarmScheduleRegistry(),
    required ShiftAlarmOccurrenceSchedule schedule,
    required ShiftAlarmOccurrenceCancel cancel,
  }) {
    return ShiftAlarmScheduleReconciler._(
      planner: planner,
      registry: registry,
      schedule: schedule,
      cancel: cancel,
    );
  }

  ShiftAlarmScheduleReconciler._({
    required this._planner,
    required this._registry,
    required this._schedule,
    required this._cancel,
  });

  final ShiftAlarmSchedulePlanner _planner;
  final ShiftAlarmScheduleRegistry _registry;

  final ShiftAlarmOccurrenceSchedule _schedule;
  final ShiftAlarmOccurrenceCancel _cancel;

  Future<ShiftAlarmReconcileResult> reconcile({
    required String userId,
    required DateTime now,
    required ShiftCrew crew,
    required Iterable<ShiftAlarm> alarms,
    required Iterable<VacationPeriod> vacationPeriods,
  }) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }

    final previousItems = await _registry.loadForUser(userId: normalizedUserId);

    var cancelledCount = 0;

    for (final item in previousItems) {
      await _cancel(notificationId: item.notificationId);

      cancelledCount++;
    }

    final desiredOccurrences = _planner.plan(
      now: now,
      crew: crew,
      alarms: alarms,
      vacationPeriods: vacationPeriods,
    );

    final scheduledItems = <ShiftAlarmScheduledItem>[];

    final notificationIds = <int, String>{};

    for (final occurrence in desiredOccurrences) {
      final notificationId = notificationIdForOccurrenceId(
        occurrence.occurrenceId,
      );

      final existingOccurrenceId = notificationIds[notificationId];

      if (existingOccurrenceId != null &&
          existingOccurrenceId != occurrence.occurrenceId) {
        throw StateError(
          'Shift alarm notification id collision: '
          '$existingOccurrenceId / ${occurrence.occurrenceId}',
        );
      }

      notificationIds[notificationId] = occurrence.occurrenceId;

      final scheduled = await _schedule(
        notificationId: notificationId,
        occurrence: occurrence,
      );

      if (!scheduled) {
        continue;
      }

      scheduledItems.add(
        ShiftAlarmScheduledItem(
          occurrenceId: occurrence.occurrenceId,
          notificationId: notificationId,
        ),
      );
    }

    await _registry.replaceForUser(
      userId: normalizedUserId,
      items: scheduledItems,
    );

    return ShiftAlarmReconcileResult(
      desiredCount: desiredOccurrences.length,
      scheduledCount: scheduledItems.length,
      cancelledCount: cancelledCount,
    );
  }

  static int notificationIdForOccurrenceId(String occurrenceId) {
    final normalizedOccurrenceId = occurrenceId.trim();

    if (normalizedOccurrenceId.isEmpty) {
      throw ArgumentError.value(
        occurrenceId,
        'occurrenceId',
        'must not be empty',
      );
    }

    const offsetBasis = 0x811c9dc5;
    const prime = 0x01000193;

    var hash = offsetBasis;

    const namespace = 'shift_alarm:';

    for (final codeUnit in '$namespace$normalizedOccurrenceId'.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * prime) & 0xffffffff;
    }

    return hash & 0x7fffffff;
  }
}
