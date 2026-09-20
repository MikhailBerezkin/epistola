import 'package:epistola/domain/models/calendar_entry.dart';
import 'package:epistola/services/spaces/calendar/calendar_entry_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarEntryMapper', () {
    test('round trips full task data', () {
      final source = CalendarEntry(
        id: 'entry-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20, 15),
        title: ' Спортзал ',
        description: ' Взять форму ',
        scheduledMinutes: 19 * 60,
        reminderMinutes: 18 * 60 + 30,
        priority: CalendarEntryPriority.high,
        colorValue: 0xFF9C27B0,
        isCompleted: true,
        completedAt: DateTime.utc(2026, 9, 20, 20),
        createdAt: DateTime.utc(2026, 9, 19, 12),
        updatedAt: DateTime.utc(2026, 9, 20, 20),
      );

      final map = CalendarEntryMapper.toMap(source);
      final restored = CalendarEntryMapper.fromMap(map);

      expect(restored.id, 'entry-1');
      expect(restored.kind, CalendarEntryKind.task);
      expect(restored.date, DateTime(2026, 9, 20));
      expect(restored.title, 'Спортзал');
      expect(restored.description, 'Взять форму');
      expect(restored.scheduledMinutes, 1140);
      expect(restored.reminderMinutes, 1110);
      expect(restored.priority, CalendarEntryPriority.high);
      expect(restored.colorValue, 0xFF9C27B0);
      expect(restored.isCompleted, isTrue);
      expect(restored.completedAt, DateTime.utc(2026, 9, 20, 20));
    });

    test('round trips simple note', () {
      final source = CalendarEntry(
        id: 'note-1',
        kind: CalendarEntryKind.note,
        date: DateTime(2026, 9, 21),
        title: 'Купить масло',
        createdAt: DateTime.utc(2026, 9, 20),
        updatedAt: DateTime.utc(2026, 9, 20),
      );

      final restored = CalendarEntryMapper.fromMap(
        CalendarEntryMapper.toMap(source),
      );

      expect(restored.kind, CalendarEntryKind.note);
      expect(restored.hasScheduledTime, isFalse);
      expect(restored.hasReminder, isFalse);
      expect(restored.priority, CalendarEntryPriority.none);
      expect(restored.isCompleted, isFalse);
    });

    test('normalizes optional text before storage', () {
      final entry = CalendarEntry(
        id: 'entry-1',
        kind: CalendarEntryKind.task,
        date: DateTime(2026, 9, 20),
        title: ' Дело ',
        description: '   ',
        createdAt: DateTime.utc(2026, 9, 20),
        updatedAt: DateTime.utc(2026, 9, 20),
      );

      final map = CalendarEntryMapper.toMap(entry);

      expect(map['title'], 'Дело');
      expect(map['description'], isNull);
    });

    test('rejects unsupported schema version', () {
      expect(
        () =>
            CalendarEntryMapper.fromMap(<String, Object?>{'schemaVersion': 99}),
        throwsFormatException,
      );
    });

    test('rejects invalid calendar day', () {
      final map = <String, Object?>{
        'schemaVersion': 1,
        'id': 'entry-1',
        'kind': 'task',
        'day': 20260231,
        'title': 'Дело',
        'priority': 'none',
        'isCompleted': false,
        'createdAt': 0,
        'updatedAt': 0,
      };

      expect(() => CalendarEntryMapper.fromMap(map), throwsFormatException);
    });

    test('rejects unknown entry kind', () {
      final map = <String, Object?>{
        'schemaVersion': 1,
        'id': 'entry-1',
        'kind': 'event',
        'day': 20260920,
        'title': 'Дело',
        'priority': 'none',
        'isCompleted': false,
        'createdAt': 0,
        'updatedAt': 0,
      };

      expect(() => CalendarEntryMapper.fromMap(map), throwsFormatException);
    });
  });
}
