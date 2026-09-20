import 'package:epistola/domain/models/calendar_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarEntry', () {
    test('normalizes entry date to day only', () {
      final entry = CalendarEntry(
        id: 'entry-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20, 18, 45),
        title: 'Спортзал',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      );

      expect(entry.date, DateTime(2026, 9, 20));
      expect(entry.dayKey, 20260920);
    });

    test('supports separate task and reminder times', () {
      final entry = CalendarEntry(
        id: 'entry-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Спортзал',
        scheduledMinutes: 19 * 60,
        reminderMinutes: 18 * 60 + 30,
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      );

      expect(entry.hasScheduledTime, isTrue);
      expect(entry.hasReminder, isTrue);
      expect(entry.scheduledMinutes, 1140);
      expect(entry.reminderMinutes, 1110);
      expect(entry.isValid, isTrue);
    });

    test('supports entry without time and reminder', () {
      final entry = CalendarEntry(
        id: 'entry-1',
        kind: CalendarEntryKind.note,
        date: DateTime(2026, 9, 20),
        title: 'Купить масло',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      );

      expect(entry.hasScheduledTime, isFalse);
      expect(entry.hasReminder, isFalse);
      expect(entry.isValid, isTrue);
    });

    test('rejects time outside one day', () {
      final entry = CalendarEntry(
        id: 'entry-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Дело',
        scheduledMinutes: 1440,
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      );

      expect(entry.isValid, isFalse);
    });

    test('completed task requires completedAt', () {
      final entry = CalendarEntry(
        id: 'entry-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Дело',
        isCompleted: true,
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      );

      expect(entry.isValid, isFalse);
    });

    test('note cannot be completed task', () {
      final entry = CalendarEntry(
        id: 'entry-1',
        kind: CalendarEntryKind.note,
        date: DateTime(2026, 9, 20),
        title: 'Заметка',
        isCompleted: true,
        completedAt: DateTime(2026, 9, 20, 12),
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      );

      expect(entry.isValid, isFalse);
    });

    test('matches the same calendar day', () {
      final entry = CalendarEntry(
        id: 'entry-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: 'Дело',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
      );

      expect(entry.occursOn(DateTime(2026, 9, 20, 23, 59)), isTrue);

      expect(entry.occursOn(DateTime(2026, 9, 21)), isFalse);
    });
  });
}
