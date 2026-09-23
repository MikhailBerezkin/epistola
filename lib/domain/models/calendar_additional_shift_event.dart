import 'substitution_shift.dart';

enum CalendarAdditionalShiftState { upcoming, occurred }

final class CalendarAdditionalShiftEvent {
  const CalendarAdditionalShiftEvent({
    required this.sourceCallId,
    required this.date,
    required this.kind,
    required this.startAt,
    required this.endAt,
  });

  /// Stable ID исходного confirmed Substitution call.
  final String sourceCallId;

  /// Календарная дата начала дополнительной смены.
  final DateTime date;

  final SubstitutionShiftKind kind;

  /// Локальное время начала рабочей смены.
  final DateTime startAt;

  /// Локальное время окончания рабочей смены.
  final DateTime endAt;

  CalendarAdditionalShiftState stateAt(DateTime now) {
    return now.isBefore(startAt)
        ? CalendarAdditionalShiftState.upcoming
        : CalendarAdditionalShiftState.occurred;
  }

  bool occursOn(DateTime value) {
    return date.year == value.year &&
        date.month == value.month &&
        date.day == value.day;
  }
}
