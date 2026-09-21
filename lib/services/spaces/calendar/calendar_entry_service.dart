import '../../../domain/models/calendar_entry.dart';
import 'calendar_entry_local_store.dart';
import 'calendar_entry_reminder_service.dart';

typedef CalendarEntryClock = DateTime Function();
typedef CalendarEntryIdFactory = String Function();

final class CalendarEntryService {
  CalendarEntryService(
    this._store, {
    CalendarEntryClock? clock,
    CalendarEntryIdFactory? idFactory,
    CalendarEntryReminderService? reminderService,
  }) : _clock = clock ?? DateTime.now,
       _idFactory = idFactory ?? _defaultIdFactory,
       _reminderService = reminderService ?? CalendarEntryReminderService();

  final CalendarEntryLocalStore _store;
  final CalendarEntryClock _clock;
  final CalendarEntryIdFactory _idFactory;
  final CalendarEntryReminderService _reminderService;

  Future<List<CalendarEntry>> loadForUser({required String userId}) {
    return _store.loadForUser(userId: userId);
  }

  Future<bool> ensureReminderPermission() {
    return _reminderService.ensurePermission();
  }

  Future<void> reconcileReminders({required String userId}) async {
    final entries = await _store.loadForUser(userId: userId);

    await _reminderService.reconcile(entries);
  }

  Future<List<CalendarEntry>> loadForDay({
    required String userId,
    required DateTime date,
  }) async {
    final entries = await _store.loadForUser(userId: userId);

    final dayEntries = entries.where((entry) => entry.occursOn(date)).toList();

    dayEntries.sort(_compareEntries);

    return dayEntries;
  }

  Future<CalendarEntry> create({
    required String userId,
    required CalendarEntryKind kind,
    required DateTime date,
    required String title,
    String? description,
    int? scheduledMinutes,
    int? reminderMinutes,
    CalendarEntryPriority priority = CalendarEntryPriority.none,
    int? colorValue,
  }) async {
    final now = _clock();

    final entry = CalendarEntry(
      id: _idFactory(),
      kind: kind,
      date: date,
      title: title.trim(),
      description: _normalizeOptionalText(description),
      scheduledMinutes: scheduledMinutes,
      reminderMinutes: reminderMinutes,
      priority: priority,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );

    if (!entry.isValid) {
      throw ArgumentError.value(
        entry,
        'entry',
        'must be a valid calendar entry',
      );
    }

    await _store.save(userId: userId, entry: entry);
    await _reminderService.sync(entry);

    return entry;
  }

  Future<CalendarEntry> update({
    required String userId,
    required CalendarEntry currentEntry,
    required CalendarEntryKind kind,
    required DateTime date,
    required String title,
    String? description,
    int? scheduledMinutes,
    int? reminderMinutes,
    CalendarEntryPriority priority = CalendarEntryPriority.none,
    int? colorValue,
  }) async {
    final isCompleted =
        kind == CalendarEntryKind.task && currentEntry.isCompleted;

    final updatedEntry = CalendarEntry(
      id: currentEntry.id,
      kind: kind,
      date: date,
      title: title.trim(),
      description: _normalizeOptionalText(description),
      scheduledMinutes: scheduledMinutes,
      reminderMinutes: reminderMinutes,
      priority: priority,
      colorValue: colorValue,
      isCompleted: isCompleted,
      completedAt: isCompleted ? currentEntry.completedAt : null,
      createdAt: currentEntry.createdAt,
      updatedAt: _clock(),
    );

    if (!updatedEntry.isValid) {
      throw ArgumentError.value(
        updatedEntry,
        'entry',
        'must be a valid calendar entry',
      );
    }

    await _store.save(userId: userId, entry: updatedEntry);
    await _reminderService.sync(updatedEntry);

    return updatedEntry;
  }

  Future<CalendarEntry> setCompleted({
    required String userId,
    required CalendarEntry entry,
    required bool isCompleted,
  }) async {
    if (entry.kind != CalendarEntryKind.task) {
      throw ArgumentError.value(entry, 'entry', 'only tasks can be completed');
    }

    final now = _clock();

    final updatedEntry = CalendarEntry(
      id: entry.id,
      kind: entry.kind,
      date: entry.date,
      title: entry.title,
      description: entry.description,
      scheduledMinutes: entry.scheduledMinutes,
      reminderMinutes: entry.reminderMinutes,
      priority: entry.priority,
      colorValue: entry.colorValue,
      isCompleted: isCompleted,
      completedAt: isCompleted ? now : null,
      createdAt: entry.createdAt,
      updatedAt: now,
    );

    await _store.save(userId: userId, entry: updatedEntry);
    await _reminderService.sync(updatedEntry);

    return updatedEntry;
  }

  Future<void> delete({
    required String userId,
    required CalendarEntry entry,
  }) async {
    await _reminderService.cancel(entry);

    await _store.delete(userId: userId, entryId: entry.id);
  }

  static int _compareEntries(CalendarEntry left, CalendarEntry right) {
    if (left.isCompleted != right.isCompleted) {
      return left.isCompleted ? 1 : -1;
    }

    if (left.isCompleted && right.isCompleted) {
      final leftCompletedAt = left.completedAt;
      final rightCompletedAt = right.completedAt;

      if (leftCompletedAt != null && rightCompletedAt != null) {
        final completedComparison = rightCompletedAt.compareTo(leftCompletedAt);

        if (completedComparison != 0) {
          return completedComparison;
        }
      }
    }

    final leftTime = left.scheduledMinutes;
    final rightTime = right.scheduledMinutes;

    if (leftTime != null && rightTime != null) {
      final timeComparison = leftTime.compareTo(rightTime);

      if (timeComparison != 0) {
        return timeComparison;
      }
    } else if (leftTime != null) {
      return -1;
    } else if (rightTime != null) {
      return 1;
    }

    return left.createdAt.compareTo(right.createdAt);
  }

  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static String _defaultIdFactory() {
    return 'entry_${DateTime.now().microsecondsSinceEpoch}';
  }
}
