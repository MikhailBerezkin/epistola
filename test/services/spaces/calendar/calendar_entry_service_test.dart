import 'package:epistola/domain/models/calendar_entry.dart';
import 'package:epistola/services/spaces/calendar/calendar_entry_local_store.dart';
import 'package:epistola/services/spaces/calendar/calendar_entry_reminder_service.dart';
import 'package:epistola/services/spaces/calendar/calendar_entry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CalendarEntryService service;

  late List<int> scheduledIds;
  late List<int> cancelledIds;

  late bool canScheduleExact;
  late bool permissionRequestResult;
  late int permissionRequestCount;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    scheduledIds = <int>[];
    cancelledIds = <int>[];

    canScheduleExact = true;
    permissionRequestResult = true;
    permissionRequestCount = 0;

    var nextId = 0;

    final reminderService = CalendarEntryReminderService(
      schedule:
          ({
            required int notificationId,
            required DateTime date,
            required int reminderMinutes,
            required String title,
            String? body,
          }) async {
            scheduledIds.add(notificationId);
            return true;
          },
      cancel: ({required int notificationId}) async {
        cancelledIds.add(notificationId);
      },
      canScheduleExact: () async => canScheduleExact,
      requestExactPermission: () async {
        permissionRequestCount += 1;
        return permissionRequestResult;
      },
    );

    service = CalendarEntryService(
      const CalendarEntryLocalStore(),
      clock: () => DateTime.utc(2026, 9, 20, 12),
      idFactory: () {
        nextId += 1;
        return 'entry-$nextId';
      },
      reminderService: reminderService,
    );
  });

  group('CalendarEntryService', () {
    test('creates and persists local entry', () async {
      final created = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: ' Спортзал ',
        scheduledMinutes: 19 * 60,
        reminderMinutes: 18 * 60 + 30,
        priority: CalendarEntryPriority.high,
      );

      expect(created.id, 'entry-1');
      expect(created.title, 'Спортзал');

      final restored = await service.loadForDay(
        userId: 'user-1',
        date: DateTime(2026, 9, 20),
      );

      expect(restored, hasLength(1));
      expect(restored.single.title, 'Спортзал');
    });

    test('loads only entries for requested day', () async {
      await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Сегодня',
      );

      await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 21),
        title: 'Завтра',
      );

      final entries = await service.loadForDay(
        userId: 'user-1',
        date: DateTime(2026, 9, 20, 23, 59),
      );

      expect(entries, hasLength(1));
      expect(entries.single.title, 'Сегодня');
    });

    test('sorts timed entries before entries without time', () async {
      await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Без времени',
      );

      await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Вечером',
        scheduledMinutes: 18 * 60,
      );

      await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Утром',
        scheduledMinutes: 9 * 60,
      );

      final entries = await service.loadForDay(
        userId: 'user-1',
        date: DateTime(2026, 9, 20),
      );

      expect(entries.map((entry) => entry.title).toList(), <String>[
        'Утром',
        'Вечером',
        'Без времени',
      ]);
    });

    test('moves completed task below active entries', () async {
      final first = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Первое',
        scheduledMinutes: 9 * 60,
      );

      await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Второе',
        scheduledMinutes: 18 * 60,
      );

      await service.setCompleted(
        userId: 'user-1',
        entry: first,
        isCompleted: true,
      );

      final entries = await service.loadForDay(
        userId: 'user-1',
        date: DateTime(2026, 9, 20),
      );

      expect(entries[0].title, 'Второе');
      expect(entries[0].isCompleted, isFalse);

      expect(entries[1].title, 'Первое');
      expect(entries[1].isCompleted, isTrue);
    });

    test('can return completed task to active state', () async {
      final entry = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Дело',
      );

      final completed = await service.setCompleted(
        userId: 'user-1',
        entry: entry,
        isCompleted: true,
      );

      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      final restored = await service.setCompleted(
        userId: 'user-1',
        entry: completed,
        isCompleted: false,
      );

      expect(restored.isCompleted, isFalse);
      expect(restored.completedAt, isNull);
    });

    test('note cannot be marked completed', () async {
      final note = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.note,
        date: DateTime(2026, 9, 20),
        title: 'Заметка',
      );

      expect(
        () => service.setCompleted(
          userId: 'user-1',
          entry: note,
          isCompleted: true,
        ),
        throwsArgumentError,
      );
    });

    test('updates entry without changing its id', () async {
      final entry = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Старое',
      );

      final updated = await service.update(
        userId: 'user-1',
        currentEntry: entry,
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Новое',
        scheduledMinutes: 15 * 60,
      );

      expect(updated.id, entry.id);
      expect(updated.title, 'Новое');

      final entries = await service.loadForDay(
        userId: 'user-1',
        date: DateTime(2026, 9, 20),
      );

      expect(entries, hasLength(1));
      expect(entries.single.title, 'Новое');
      expect(entries.single.scheduledMinutes, 15 * 60);
    });

    test('deletes entry', () async {
      final entry = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Удалить',
      );

      await service.delete(userId: 'user-1', entry: entry);

      final entries = await service.loadForDay(
        userId: 'user-1',
        date: DateTime(2026, 9, 20),
      );

      expect(entries, isEmpty);
    });

    test('create schedules reminder', () async {
      final entry = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 25),
        title: 'Будильник',
        reminderMinutes: 18 * 60 + 30,
      );

      expect(scheduledIds, <int>[
        CalendarEntryReminderService.notificationIdForEntryId(entry.id),
      ]);
    });

    test('update reschedules reminder with same notification id', () async {
      final entry = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 25),
        title: 'Будильник',
        reminderMinutes: 18 * 60,
      );

      scheduledIds.clear();

      final updated = await service.update(
        userId: 'user-1',
        currentEntry: entry,
        kind: entry.kind,
        date: entry.date,
        title: entry.title,
        reminderMinutes: 19 * 60,
      );

      expect(updated.id, entry.id);

      expect(scheduledIds, <int>[
        CalendarEntryReminderService.notificationIdForEntryId(entry.id),
      ]);
    });

    test('turning reminder off cancels scheduled notification', () async {
      final entry = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 25),
        title: 'Будильник',
        reminderMinutes: 18 * 60,
      );

      cancelledIds.clear();

      await service.update(
        userId: 'user-1',
        currentEntry: entry,
        kind: entry.kind,
        date: entry.date,
        title: entry.title,
        reminderMinutes: null,
      );

      expect(cancelledIds, <int>[
        CalendarEntryReminderService.notificationIdForEntryId(entry.id),
      ]);
    });

    test('completing task cancels its reminder', () async {
      final entry = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 25),
        title: 'Дело',
        reminderMinutes: 18 * 60,
      );

      cancelledIds.clear();

      await service.setCompleted(
        userId: 'user-1',
        entry: entry,
        isCompleted: true,
      );

      expect(cancelledIds, <int>[
        CalendarEntryReminderService.notificationIdForEntryId(entry.id),
      ]);
    });

    test('restoring task schedules its reminder again', () async {
      final entry = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 25),
        title: 'Дело',
        reminderMinutes: 18 * 60,
      );

      final completed = await service.setCompleted(
        userId: 'user-1',
        entry: entry,
        isCompleted: true,
      );

      scheduledIds.clear();

      await service.setCompleted(
        userId: 'user-1',
        entry: completed,
        isCompleted: false,
      );

      expect(scheduledIds, <int>[
        CalendarEntryReminderService.notificationIdForEntryId(entry.id),
      ]);
    });

    test('delete cancels reminder before removing entry', () async {
      final entry = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 25),
        title: 'Удалить',
        reminderMinutes: 18 * 60,
      );

      cancelledIds.clear();

      await service.delete(userId: 'user-1', entry: entry);

      expect(cancelledIds, <int>[
        CalendarEntryReminderService.notificationIdForEntryId(entry.id),
      ]);

      final entries = await service.loadForUser(userId: 'user-1');

      expect(entries, isEmpty);
    });

    test('ensureReminderPermission uses existing permission', () async {
      canScheduleExact = true;

      final allowed = await service.ensureReminderPermission();

      expect(allowed, isTrue);
      expect(permissionRequestCount, 0);
    });

    test('ensureReminderPermission requests missing permission', () async {
      canScheduleExact = false;
      permissionRequestResult = true;

      final allowed = await service.ensureReminderPermission();

      expect(allowed, isTrue);
      expect(permissionRequestCount, 1);
    });

    test('reconcileReminders syncs persisted entries', () async {
      final active = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 25),
        title: 'Активное',
        reminderMinutes: 18 * 60,
      );

      final plain = await service.create(
        userId: 'user-1',
        kind: CalendarEntryKind.note,
        date: DateTime(2026, 9, 25),
        title: 'Без будильника',
      );

      scheduledIds.clear();
      cancelledIds.clear();

      await service.reconcileReminders(userId: 'user-1');

      expect(scheduledIds, <int>[
        CalendarEntryReminderService.notificationIdForEntryId(active.id),
      ]);

      expect(cancelledIds, <int>[
        CalendarEntryReminderService.notificationIdForEntryId(plain.id),
      ]);
    });
  });
}
