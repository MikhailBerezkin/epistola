import '../../../domain/models/calendar_additional_shift_event.dart';
import '../../../domain/models/shift_cycle.dart';
import '../../../domain/models/substitution_shift.dart';
import '../../../domain/models/vacation_period.dart';
import 'shift_schedule_calculator.dart';

final class ShiftMonthHoursSummary {
  const ShiftMonthHoursSummary({
    required this.regularMinutes,
    required this.additionalMinutes,
  });

  final int regularMinutes;
  final int additionalMinutes;

  int get totalMinutes => regularMinutes + additionalMinutes;

  double get regularHours => regularMinutes / 60;
  double get additionalHours => additionalMinutes / 60;
  double get totalHours => totalMinutes / 60;
}

final class ShiftMonthHoursCalculator {
  const ShiftMonthHoursCalculator({
    this._scheduleCalculator = const ShiftScheduleCalculator(),
  });

  static const int fullShiftMinutes = 11 * 60 + 30;

  static const int nightStartMonthMinutes = 4 * 60;

  static const int nightNextMonthMinutes =
      fullShiftMinutes - nightStartMonthMinutes;

  final ShiftScheduleCalculator _scheduleCalculator;

  ShiftMonthHoursSummary calculate({
    required DateTime month,
    required ShiftCrew crew,
    required Iterable<VacationPeriod> vacationPeriods,
    required Iterable<CalendarAdditionalShiftEvent> additionalShifts,
  }) {
    final normalizedMonth = DateTime(month.year, month.month);

    return ShiftMonthHoursSummary(
      regularMinutes: _regularMinutesForMonth(
        month: normalizedMonth,
        crew: crew,
        vacationPeriods: vacationPeriods,
      ),
      additionalMinutes: _additionalMinutesForMonth(
        month: normalizedMonth,
        additionalShifts: additionalShifts,
      ),
    );
  }

  int _regularMinutesForMonth({
    required DateTime month,
    required ShiftCrew crew,
    required Iterable<VacationPeriod> vacationPeriods,
  }) {
    var totalMinutes = 0;

    final firstDay = DateTime(month.year, month.month, 1);

    final lastDay = DateTime(month.year, month.month + 1, 0);

    // Берём также предыдущий день:
    // ночная смена предыдущего месяца может дать
    // 7.5 часа в первый день текущего месяца.
    var date = firstDay.subtract(const Duration(days: 1));

    while (!date.isAfter(lastDay)) {
      final phase = _scheduleCalculator.phaseFor(date: date, crew: crew);

      if (phase.isDayShift) {
        if (!_isVacationDate(date, vacationPeriods) &&
            _isInMonth(date, month)) {
          totalMinutes += fullShiftMinutes;
        }
      }

      if (phase.isNightShift) {
        if (!_isVacationDate(date, vacationPeriods) &&
            _isInMonth(date, month)) {
          totalMinutes += nightStartMonthMinutes;
        }

        final nextDate = date.add(const Duration(days: 1));

        if (!_isVacationDate(nextDate, vacationPeriods) &&
            _isInMonth(nextDate, month)) {
          totalMinutes += nightNextMonthMinutes;
        }
      }

      date = date.add(const Duration(days: 1));
    }

    return totalMinutes;
  }

  int _additionalMinutesForMonth({
    required DateTime month,
    required Iterable<CalendarAdditionalShiftEvent> additionalShifts,
  }) {
    var totalMinutes = 0;

    for (final event in additionalShifts) {
      switch (event.kind) {
        case SubstitutionShiftKind.day:
          if (_isInMonth(event.date, month)) {
            totalMinutes += fullShiftMinutes;
          }

        case SubstitutionShiftKind.night:
          if (_isInMonth(event.date, month)) {
            totalMinutes += nightStartMonthMinutes;
          }

          final nextDate = event.date.add(const Duration(days: 1));

          if (_isInMonth(nextDate, month)) {
            totalMinutes += nightNextMonthMinutes;
          }
      }
    }

    return totalMinutes;
  }

  static bool _isInMonth(DateTime date, DateTime month) {
    return date.year == month.year && date.month == month.month;
  }

  static bool _isVacationDate(
    DateTime date,
    Iterable<VacationPeriod> vacationPeriods,
  ) {
    return vacationPeriods.any((period) => period.contains(date));
  }
}
