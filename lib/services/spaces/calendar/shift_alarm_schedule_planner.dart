import '../../../domain/models/shift_alarm.dart';
import '../../../domain/models/shift_alarm_occurrence.dart';
import '../../../domain/models/shift_cycle.dart';
import '../../../domain/models/vacation_period.dart';
import 'shift_alarm_occurrence_resolver.dart';

final class ShiftAlarmSchedulePlanner {
  const ShiftAlarmSchedulePlanner({this.daysAhead = 32});

  final int daysAhead;

  List<ShiftAlarmOccurrence> plan({
    required DateTime now,
    required ShiftCrew crew,
    required Iterable<ShiftAlarm> alarms,
    required Iterable<VacationPeriod> vacationPeriods,
  }) {
    if (daysAhead <= 0) {
      return const <ShiftAlarmOccurrence>[];
    }

    const resolver = ShiftAlarmOccurrenceResolver();

    final startDate = DateTime(now.year, now.month, now.day);

    final result = <ShiftAlarmOccurrence>[];

    for (var offset = 0; offset < daysAhead; offset++) {
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day + offset,
      );

      final alarmsForDate = resolver.alarmsForDate(
        date: date,
        crew: crew,
        alarms: alarms,
        vacationPeriods: vacationPeriods,
      );

      for (final alarm in alarmsForDate) {
        final occurrence = ShiftAlarmOccurrence(alarm: alarm, date: date);

        // Для сегодняшнего дня не ставим уже прошедшие сигналы.
        if (!occurrence.scheduledAt.isAfter(now)) {
          continue;
        }

        result.add(occurrence);
      }
    }

    result.sort(
      (first, second) => first.scheduledAt.compareTo(second.scheduledAt),
    );

    return result;
  }
}
