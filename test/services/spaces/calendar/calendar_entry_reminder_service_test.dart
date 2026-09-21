import 'package:epistola/domain/models/calendar_entry.dart';
import 'package:epistola/services/spaces/calendar/calendar_entry_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarEntryReminderService', () {
    test('creates stable notification id from entry id', () {
      final first = CalendarEntryReminderService.notificationIdForEntryId(
        'entry-123',
      );

      final second = CalendarEntryReminderService.notificationIdForEntryId(
        'entry-123',
      );

      final other = CalendarEntryReminderService.notificationIdForEntryId(
        'entry-456',
      );

      expect(first, second);
      expect(first, isNot(other));
      expect(first, inInclusiveRange(0, 0x7fffffff));
    });

    test('rejects empty entry id', () {
      expect(
        () => CalendarEntryReminderService.notificationIdForEntryId('   '),
        throwsArgumentError,
      );
    });

    test(
      'does not request exact permission when it is already granted',
      () async {
        var requestCount = 0;

        final service = CalendarEntryReminderService(
          schedule:
              ({
                required int notificationId,
                required DateTime date,
                required int reminderMinutes,
                required String title,
                String? body,
              }) async {
                return true;
              },
          cancel: ({required int notificationId}) async {},
          canScheduleExact: () async => true,
          requestExactPermission: () async {
            requestCount += 1;
            return true;
          },
        );

        final allowed = await service.ensurePermission();

        expect(allowed, isTrue);
        expect(requestCount, 0);
      },
    );

    test('requests exact permission when it is not granted yet', () async {
      var requestCount = 0;

      final service = CalendarEntryReminderService(
        schedule:
            ({
              required int notificationId,
              required DateTime date,
              required int reminderMinutes,
              required String title,
              String? body,
            }) async {
              return true;
            },
        cancel: ({required int notificationId}) async {},
        canScheduleExact: () async => false,
        requestExactPermission: () async {
          requestCount += 1;
          return true;
        },
      );

      final allowed = await service.ensurePermission();

      expect(allowed, isTrue);
      expect(requestCount, 1);
    });

    test('returns false when exact permission request is denied', () async {
      final service = CalendarEntryReminderService(
        schedule:
            ({
              required int notificationId,
              required DateTime date,
              required int reminderMinutes,
              required String title,
              String? body,
            }) async {
              return true;
            },
        cancel: ({required int notificationId}) async {},
        canScheduleExact: () async => false,
        requestExactPermission: () async => false,
      );

      final allowed = await service.ensurePermission();

      expect(allowed, isFalse);
    });

    test('schedules active task with reminder', () async {
      int? scheduledId;
      DateTime? scheduledDate;
      int? scheduledMinutes;
      String? scheduledTitle;
      String? scheduledBody;

      final service = CalendarEntryReminderService(
        schedule:
            ({
              required int notificationId,
              required DateTime date,
              required int reminderMinutes,
              required String title,
              String? body,
            }) async {
              scheduledId = notificationId;
              scheduledDate = date;
              scheduledMinutes = reminderMinutes;
              scheduledTitle = title;
              scheduledBody = body;

              return true;
            },
        cancel: ({required int notificationId}) async {},
        canScheduleExact: () async => true,
        requestExactPermission: () async => true,
      );

      final entry = _entry(
        id: 'task-1',
        kind: CalendarEntryKind.task,
        title: 'Спортзал',
        date: DateTime(2026, 9, 25),
        reminderMinutes: 18 * 60 + 30,
      );

      final scheduled = await service.sync(entry);

      expect(scheduled, isTrue);

      expect(
        scheduledId,
        CalendarEntryReminderService.notificationIdForEntryId(entry.id),
      );

      expect(scheduledDate, DateTime(2026, 9, 25));
      expect(scheduledMinutes, 18 * 60 + 30);
      expect(scheduledTitle, 'Спортзал');
      expect(scheduledBody, 'Напоминание о деле');
    });

    test('uses note body for note reminder', () async {
      String? scheduledBody;

      final service = CalendarEntryReminderService(
        schedule:
            ({
              required int notificationId,
              required DateTime date,
              required int reminderMinutes,
              required String title,
              String? body,
            }) async {
              scheduledBody = body;
              return true;
            },
        cancel: ({required int notificationId}) async {},
        canScheduleExact: () async => true,
        requestExactPermission: () async => true,
      );

      final entry = _entry(
        id: 'note-1',
        kind: CalendarEntryKind.note,
        title: 'Купить фильтр',
        reminderMinutes: 10 * 60,
      );

      await service.sync(entry);

      expect(scheduledBody, 'Напоминание о заметке');
    });

    test('cancels entry without reminder', () async {
      final cancelledIds = <int>[];
      var scheduleCount = 0;

      final service = CalendarEntryReminderService(
        schedule:
            ({
              required int notificationId,
              required DateTime date,
              required int reminderMinutes,
              required String title,
              String? body,
            }) async {
              scheduleCount += 1;
              return true;
            },
        cancel: ({required int notificationId}) async {
          cancelledIds.add(notificationId);
        },
        canScheduleExact: () async => true,
        requestExactPermission: () async => true,
      );

      final entry = _entry(
        id: 'task-no-reminder',
        kind: CalendarEntryKind.task,
        title: 'Без будильника',
      );

      final scheduled = await service.sync(entry);

      expect(scheduled, isFalse);
      expect(scheduleCount, 0);

      expect(cancelledIds, <int>[
        CalendarEntryReminderService.notificationIdForEntryId(entry.id),
      ]);
    });

    test('cancels completed task even when reminder exists', () async {
      final cancelledIds = <int>[];
      var scheduleCount = 0;

      final service = CalendarEntryReminderService(
        schedule:
            ({
              required int notificationId,
              required DateTime date,
              required int reminderMinutes,
              required String title,
              String? body,
            }) async {
              scheduleCount += 1;
              return true;
            },
        cancel: ({required int notificationId}) async {
          cancelledIds.add(notificationId);
        },
        canScheduleExact: () async => true,
        requestExactPermission: () async => true,
      );

      final entry = _entry(
        id: 'completed-task',
        kind: CalendarEntryKind.task,
        title: 'Выполнено',
        reminderMinutes: 12 * 60,
        isCompleted: true,
      );

      final scheduled = await service.sync(entry);

      expect(scheduled, isFalse);
      expect(scheduleCount, 0);

      expect(cancelledIds, <int>[
        CalendarEntryReminderService.notificationIdForEntryId(entry.id),
      ]);
    });

    test(
      'reconcile schedules active reminders and cancels inactive ones',
      () async {
        final scheduledIds = <int>[];
        final cancelledIds = <int>[];

        final service = CalendarEntryReminderService(
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
          canScheduleExact: () async => true,
          requestExactPermission: () async => true,
        );

        final active = _entry(
          id: 'active',
          kind: CalendarEntryKind.task,
          title: 'Активное',
          reminderMinutes: 9 * 60,
        );

        final plain = _entry(
          id: 'plain',
          kind: CalendarEntryKind.note,
          title: 'Без будильника',
        );

        final completed = _entry(
          id: 'completed',
          kind: CalendarEntryKind.task,
          title: 'Завершено',
          reminderMinutes: 20 * 60,
          isCompleted: true,
        );

        await service.reconcile(<CalendarEntry>[active, plain, completed]);

        expect(scheduledIds, <int>[
          CalendarEntryReminderService.notificationIdForEntryId(active.id),
        ]);

        expect(cancelledIds, <int>[
          CalendarEntryReminderService.notificationIdForEntryId(plain.id),
          CalendarEntryReminderService.notificationIdForEntryId(completed.id),
        ]);
      },
    );
  });
}

CalendarEntry _entry({
  required String id,
  required CalendarEntryKind kind,
  required String title,
  DateTime? date,
  int? reminderMinutes,
  bool isCompleted = false,
}) {
  return CalendarEntry(
    id: id,
    kind: kind,
    date: date ?? DateTime(2026, 9, 25),
    title: title,
    reminderMinutes: reminderMinutes,
    isCompleted: isCompleted,
    completedAt: isCompleted ? DateTime(2026, 9, 25, 12) : null,
    createdAt: DateTime(2026, 9, 20, 10),
    updatedAt: DateTime(2026, 9, 20, 10),
  );
}
