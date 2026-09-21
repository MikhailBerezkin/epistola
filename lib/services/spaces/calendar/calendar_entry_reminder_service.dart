import '../../../domain/models/calendar_entry.dart';
import '../../notification_service.dart';

typedef CalendarEntryReminderSchedule =
    Future<bool> Function({
      required int notificationId,
      required DateTime date,
      required int reminderMinutes,
      required String title,
      String? body,
    });

typedef CalendarEntryReminderCancel =
    Future<void> Function({required int notificationId});

typedef CalendarEntryReminderPermissionCheck = Future<bool> Function();

typedef CalendarEntryReminderPermissionRequest = Future<bool> Function();

final class CalendarEntryReminderService {
  CalendarEntryReminderService({
    CalendarEntryReminderSchedule? schedule,
    CalendarEntryReminderCancel? cancel,
    CalendarEntryReminderPermissionCheck? canScheduleExact,
    CalendarEntryReminderPermissionRequest? requestExactPermission,
  }) : _schedule = schedule ?? NotificationService.scheduleCalendarReminder,
       _cancel = cancel ?? NotificationService.cancelCalendarReminder,
       _canScheduleExact =
           canScheduleExact ??
           NotificationService.canScheduleExactCalendarReminders,
       _requestExactPermission =
           requestExactPermission ??
           NotificationService.requestExactCalendarReminderPermission;

  final CalendarEntryReminderSchedule _schedule;
  final CalendarEntryReminderCancel _cancel;
  final CalendarEntryReminderPermissionCheck _canScheduleExact;
  final CalendarEntryReminderPermissionRequest _requestExactPermission;

  Future<bool> ensurePermission() async {
    if (await _canScheduleExact()) {
      return true;
    }

    return _requestExactPermission();
  }

  Future<bool> sync(CalendarEntry entry) async {
    final notificationId = notificationIdForEntryId(entry.id);

    if (!entry.hasReminder || entry.isCompleted) {
      await _cancel(notificationId: notificationId);
      return false;
    }

    return _schedule(
      notificationId: notificationId,
      date: entry.date,
      reminderMinutes: entry.reminderMinutes!,
      title: entry.title,
      body: _notificationBody(entry),
    );
  }

  Future<void> reconcile(Iterable<CalendarEntry> entries) async {
    for (final entry in entries) {
      await sync(entry);
    }
  }

  Future<void> cancel(CalendarEntry entry) {
    return _cancel(notificationId: notificationIdForEntryId(entry.id));
  }

  static int notificationIdForEntryId(String entryId) {
    if (entryId.trim().isEmpty) {
      throw ArgumentError.value(entryId, 'entryId', 'must not be empty');
    }

    const offsetBasis = 0x811c9dc5;
    const prime = 0x01000193;

    var hash = offsetBasis;

    for (final codeUnit in entryId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * prime) & 0xffffffff;
    }

    return hash & 0x7fffffff;
  }

  static String _notificationBody(CalendarEntry entry) {
    return switch (entry.kind) {
      CalendarEntryKind.task => 'Напоминание о деле',
      CalendarEntryKind.note => 'Напоминание о заметке',
    };
  }
}
