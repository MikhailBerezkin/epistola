import 'package:epistola/domain/models/calendar_entry.dart';
import 'package:epistola/services/spaces/calendar/calendar_entry_day_markers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarEntryDayMarkers', () {
    test('returns empty markers for empty day', () {
      const markers = CalendarEntryDayMarkers.empty();

      expect(markers.hasPlainEntry, isFalse);
      expect(markers.hasReminder, isFalse);
      expect(markers.highestPriority, CalendarEntryPriority.none);
      expect(markers.hasAnyMarker, isFalse);
    });

    test('plain entry shows note marker', () {
      final markers = CalendarEntryDayMarkers.fromEntries(<CalendarEntry>[
        _entry(id: 'entry-1', priority: CalendarEntryPriority.low),
      ]);

      expect(markers.hasPlainEntry, isTrue);
      expect(markers.hasReminder, isFalse);
      expect(markers.highestPriority, CalendarEntryPriority.low);
    });

    test('entry with reminder shows bell marker', () {
      final markers = CalendarEntryDayMarkers.fromEntries(<CalendarEntry>[
        _entry(id: 'entry-1', reminderMinutes: 18 * 60),
      ]);

      expect(markers.hasPlainEntry, isFalse);
      expect(markers.hasReminder, isTrue);
    });

    test('mixed entries can show both icons', () {
      final markers = CalendarEntryDayMarkers.fromEntries(<CalendarEntry>[
        _entry(id: 'plain'),
        _entry(id: 'reminder', reminderMinutes: 10 * 60),
      ]);

      expect(markers.hasPlainEntry, isTrue);
      expect(markers.hasReminder, isTrue);
    });

    test('uses highest active priority', () {
      final markers = CalendarEntryDayMarkers.fromEntries(<CalendarEntry>[
        _entry(id: 'low', priority: CalendarEntryPriority.low),
        _entry(id: 'high', priority: CalendarEntryPriority.high),
        _entry(id: 'medium', priority: CalendarEntryPriority.medium),
      ]);

      expect(markers.highestPriority, CalendarEntryPriority.high);
    });

    test('completed task does not affect markers', () {
      final markers = CalendarEntryDayMarkers.fromEntries(<CalendarEntry>[
        _entry(
          id: 'completed',
          reminderMinutes: 18 * 60,
          priority: CalendarEntryPriority.high,
          isCompleted: true,
        ),
        _entry(id: 'active', priority: CalendarEntryPriority.low),
      ]);

      expect(markers.hasPlainEntry, isTrue);
      expect(markers.hasReminder, isFalse);
      expect(markers.highestPriority, CalendarEntryPriority.low);
    });
  });
}

CalendarEntry _entry({
  required String id,
  int? reminderMinutes,
  CalendarEntryPriority priority = CalendarEntryPriority.none,
  bool isCompleted = false,
}) {
  return CalendarEntry(
    id: id,
    kind: CalendarEntryKind.task,
    date: DateTime(2026, 9, 20),
    title: id,
    reminderMinutes: reminderMinutes,
    priority: priority,
    isCompleted: isCompleted,
    completedAt: isCompleted ? DateTime.utc(2026, 9, 20, 20) : null,
    createdAt: DateTime.utc(2026, 9, 20, 10),
    updatedAt: DateTime.utc(2026, 9, 20, 10),
  );
}
