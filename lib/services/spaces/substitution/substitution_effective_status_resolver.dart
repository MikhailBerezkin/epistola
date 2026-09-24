import '../../../domain/models/substitution_participant.dart';
import '../../../domain/models/vacation_period.dart';

final class SubstitutionEffectiveStatusResolver {
  const SubstitutionEffectiveStatusResolver();

  SubstitutionParticipantStatus resolve({
    required SubstitutionParticipant participant,
    required Iterable<VacationPeriod> vacationPeriods,
    required DateTime date,
  }) {
    if (participant.isRemoved) {
      return SubstitutionParticipantStatus.removed;
    }

    if (participant.isSick) {
      return SubstitutionParticipantStatus.sick;
    }

    if (participant.isOnVacation) {
      return SubstitutionParticipantStatus.vacation;
    }

    final isVacationDate = vacationPeriods.any(
      (period) =>
          period.userId.trim() == participant.userId.trim() &&
          period.contains(date),
    );

    if (isVacationDate) {
      return SubstitutionParticipantStatus.vacation;
    }

    return SubstitutionParticipantStatus.active;
  }
}
