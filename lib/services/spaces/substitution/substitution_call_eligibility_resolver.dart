import '../../../domain/models/shift_cycle.dart';
import '../../../domain/models/substitution_shift.dart';
import '../../../domain/models/vacation_period.dart';
import '../calendar/shift_schedule_calculator.dart';

enum SubstitutionCallIneligibilityReason { missingCrew, vacation, workShift }

final class SubstitutionCallUnavailableException implements Exception {
  const SubstitutionCallUnavailableException({
    required this.userId,
    required this.shift,
    required this.reason,
  });

  final String userId;
  final SubstitutionShift shift;
  final SubstitutionCallIneligibilityReason reason;

  @override
  String toString() {
    return 'Participant $userId is unavailable for '
        '${shift.year}-${shift.month}-${shift.day} ${shift.kind.name}: '
        '${reason.name}.';
  }
}

final class SubstitutionCallEligibility {
  const SubstitutionCallEligibility.eligible() : reason = null;

  const SubstitutionCallEligibility.unavailable(this.reason);

  final SubstitutionCallIneligibilityReason? reason;

  bool get isEligible => reason == null;
}

final class SubstitutionCallEligibilityResolver {
  const SubstitutionCallEligibilityResolver({
    this._scheduleCalculator = const ShiftScheduleCalculator(),
  });

  final ShiftScheduleCalculator _scheduleCalculator;

  SubstitutionCallEligibility resolve({
    required String userId,
    required ShiftCrew? crew,
    required SubstitutionShift shift,
    required Iterable<VacationPeriod> vacationPeriods,
  }) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'userId must be non-empty.');
    }

    if (crew == null) {
      return const SubstitutionCallEligibility.unavailable(
        SubstitutionCallIneligibilityReason.missingCrew,
      );
    }

    if (_overlapsVacation(
      userId: normalizedUserId,
      shift: shift,
      vacationPeriods: vacationPeriods,
    )) {
      return const SubstitutionCallEligibility.unavailable(
        SubstitutionCallIneligibilityReason.vacation,
      );
    }

    final phase = _scheduleCalculator.phaseFor(
      date: shift.calendarDateUtc,
      crew: crew,
    );

    if (!_isShiftAllowed(phase: phase, kind: shift.kind)) {
      return const SubstitutionCallEligibility.unavailable(
        SubstitutionCallIneligibilityReason.workShift,
      );
    }

    return const SubstitutionCallEligibility.eligible();
  }

  bool _overlapsVacation({
    required String userId,
    required SubstitutionShift shift,
    required Iterable<VacationPeriod> vacationPeriods,
  }) {
    final startDate = shift.calendarDateUtc;

    for (final period in vacationPeriods) {
      if (period.userId.trim() != userId) {
        continue;
      }

      if (period.contains(startDate)) {
        return true;
      }

      if (shift.endsOnNextCalendarDay &&
          period.contains(startDate.add(const Duration(days: 1)))) {
        return true;
      }
    }

    return false;
  }

  bool _isShiftAllowed({
    required ShiftCyclePhase phase,
    required SubstitutionShiftKind kind,
  }) {
    return switch (phase) {
      ShiftCyclePhase.day1 ||
      ShiftCyclePhase.day2 ||
      ShiftCyclePhase.night1 ||
      ShiftCyclePhase.night2 => false,

      ShiftCyclePhase.offBeforeNight => true,

      ShiftCyclePhase.recovery => kind == SubstitutionShiftKind.night,

      ShiftCyclePhase.offAfterRecovery1 => true,

      ShiftCyclePhase.offAfterRecovery2 => kind == SubstitutionShiftKind.day,
    };
  }
}
