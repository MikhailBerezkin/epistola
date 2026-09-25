import '../../../domain/models/shift_alarm.dart';
import '../../../domain/models/shift_cycle.dart';
import '../../../domain/models/vacation_period.dart';
import 'shift_schedule_calculator.dart';

final class ShiftAlarmOccurrenceResolver {
  const ShiftAlarmOccurrenceResolver();

  final ShiftScheduleCalculator _calculator = const ShiftScheduleCalculator();

  List<ShiftAlarm> alarmsForDate({
    required DateTime date,
    required ShiftCrew crew,
    required Iterable<ShiftAlarm> alarms,
    required Iterable<VacationPeriod> vacationPeriods,
  }) {
    final phase = _calculator.phaseFor(date: date, crew: crew);

    final isVacation = vacationPeriods.any((period) => period.contains(date));

    final matching = alarms
        .where((alarm) {
          if (!alarm.isValid || !alarm.enabled) {
            return false;
          }

          if (alarm.phase != phase) {
            return false;
          }

          return switch (alarm.scope) {
            ShiftAlarmScope.work => !isVacation,
            ShiftAlarmScope.always => true,
            ShiftAlarmScope.vacation => isVacation,
          };
        })
        .toList(growable: false);

    matching.sort((first, second) {
      final timeComparison = first.minutesOfDay.compareTo(second.minutesOfDay);

      if (timeComparison != 0) {
        return timeComparison;
      }

      return first.title.compareTo(second.title);
    });

    return matching;
  }
}
