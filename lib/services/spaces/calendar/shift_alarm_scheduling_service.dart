import '../../../domain/models/shift_cycle.dart';
import '../../../domain/models/vacation_period.dart';
import '../../notification_service.dart';
import 'shift_alarm_local_store.dart';
import 'shift_alarm_schedule_reconciler.dart';

final class ShiftAlarmSchedulingService {
  factory ShiftAlarmSchedulingService({
    ShiftAlarmLocalStore store = const ShiftAlarmLocalStore(),
    ShiftAlarmScheduleReconciler? reconciler,
  }) {
    return ShiftAlarmSchedulingService._(
      store: store,
      reconciler:
          reconciler ??
          ShiftAlarmScheduleReconciler(
            schedule: NotificationService.scheduleShiftAlarmOccurrence,
            cancel: NotificationService.cancelShiftAlarmOccurrence,
          ),
    );
  }

  ShiftAlarmSchedulingService._({
    required this._store,
    required this._reconciler,
  });

  final ShiftAlarmLocalStore _store;
  final ShiftAlarmScheduleReconciler _reconciler;

  Future<ShiftAlarmReconcileResult> reconcile({
    required String userId,
    required ShiftCrew crew,
    required Iterable<VacationPeriod> vacationPeriods,
    DateTime? now,
  }) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }

    final alarms = await _store.loadForUser(userId: normalizedUserId);

    return _reconciler.reconcile(
      userId: normalizedUserId,
      now: now ?? DateTime.now(),
      crew: crew,
      alarms: alarms,
      vacationPeriods: vacationPeriods,
    );
  }
}
