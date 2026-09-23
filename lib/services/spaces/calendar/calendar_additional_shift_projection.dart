import '../../../domain/models/calendar_additional_shift_event.dart';
import '../../../domain/models/substitution_confirmed_call.dart';

final class CalendarAdditionalShiftProjection {
  const CalendarAdditionalShiftProjection();

  List<CalendarAdditionalShiftEvent> fromConfirmedCalls(
    Iterable<SubstitutionConfirmedCall> calls,
  ) {
    final seenCallIds = <String>{};
    final events = <CalendarAdditionalShiftEvent>[];

    for (final call in calls) {
      if (!seenCallIds.add(call.callId)) {
        continue;
      }

      final shift = call.shift;

      final date = DateTime(shift.year, shift.month, shift.day);

      final startAt = DateTime(
        shift.year,
        shift.month,
        shift.day,
        shift.startHour,
      );

      final endDate = shift.endsOnNextCalendarDay
          ? date.add(const Duration(days: 1))
          : date;

      final endAt = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        shift.endHour,
      );

      events.add(
        CalendarAdditionalShiftEvent(
          sourceCallId: call.callId,
          date: date,
          kind: shift.kind,
          startAt: startAt,
          endAt: endAt,
        ),
      );
    }

    events.sort((first, second) {
      final startComparison = first.startAt.compareTo(second.startAt);

      if (startComparison != 0) {
        return startComparison;
      }

      return first.sourceCallId.compareTo(second.sourceCallId);
    });

    return List<CalendarAdditionalShiftEvent>.unmodifiable(events);
  }
}
