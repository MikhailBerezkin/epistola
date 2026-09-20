import '../../../domain/models/calendar_entry.dart';

final class CalendarEntryDayMarkers {
  const CalendarEntryDayMarkers({
    required this.hasPlainEntry,
    required this.hasReminder,
    required this.highestPriority,
  });

  const CalendarEntryDayMarkers.empty()
    : hasPlainEntry = false,
      hasReminder = false,
      highestPriority = CalendarEntryPriority.none;

  final bool hasPlainEntry;
  final bool hasReminder;
  final CalendarEntryPriority highestPriority;

  bool get hasPriority {
    return highestPriority != CalendarEntryPriority.none;
  }

  bool get hasAnyMarker {
    return hasPlainEntry || hasReminder || hasPriority;
  }

  static CalendarEntryDayMarkers fromEntries(Iterable<CalendarEntry> entries) {
    var hasPlainEntry = false;
    var hasReminder = false;
    var highestPriority = CalendarEntryPriority.none;

    for (final entry in entries) {
      if (entry.isCompleted) {
        continue;
      }

      if (entry.hasReminder) {
        hasReminder = true;
      } else {
        hasPlainEntry = true;
      }

      if (_priorityRank(entry.priority) > _priorityRank(highestPriority)) {
        highestPriority = entry.priority;
      }
    }

    return CalendarEntryDayMarkers(
      hasPlainEntry: hasPlainEntry,
      hasReminder: hasReminder,
      highestPriority: highestPriority,
    );
  }

  static int _priorityRank(CalendarEntryPriority priority) {
    return switch (priority) {
      CalendarEntryPriority.none => 0,
      CalendarEntryPriority.low => 1,
      CalendarEntryPriority.medium => 2,
      CalendarEntryPriority.high => 3,
    };
  }
}
