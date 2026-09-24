import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/domain/models/vacation_period.dart';
import 'package:epistola/services/spaces/substitution/substitution_effective_status_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = SubstitutionEffectiveStatusResolver();

  test('keeps active participant active outside vacation', () {
    final status = resolver.resolve(
      participant: _participant(),
      vacationPeriods: const [],
      date: DateTime(2026, 9, 24),
    );

    expect(status, SubstitutionParticipantStatus.active);
  });

  test('projects active participant into vacation during calendar period', () {
    final status = resolver.resolve(
      participant: _participant(),
      vacationPeriods: [
        _vacation(start: DateTime(2026, 9, 20), end: DateTime(2026, 9, 30)),
      ],
      date: DateTime(2026, 9, 24),
    );

    expect(status, SubstitutionParticipantStatus.vacation);
  });

  test('returns participant to active after calendar vacation ends', () {
    final status = resolver.resolve(
      participant: _participant(),
      vacationPeriods: [
        _vacation(start: DateTime(2026, 9, 20), end: DateTime(2026, 9, 23)),
      ],
      date: DateTime(2026, 9, 24),
    );

    expect(status, SubstitutionParticipantStatus.active);
  });

  test('does not use vacation belonging to another user', () {
    final status = resolver.resolve(
      participant: _participant(),
      vacationPeriods: [
        VacationPeriod(
          userId: 'user-2',
          slot: 1,
          startDate: DateTime(2026, 9, 20),
          endDate: DateTime(2026, 9, 30),
        ),
      ],
      date: DateTime(2026, 9, 24),
    );

    expect(status, SubstitutionParticipantStatus.active);
  });

  test('sick status overrides calendar vacation', () {
    final status = resolver.resolve(
      participant: _participant(status: SubstitutionParticipantStatus.sick),
      vacationPeriods: [
        _vacation(start: DateTime(2026, 9, 20), end: DateTime(2026, 9, 30)),
      ],
      date: DateTime(2026, 9, 24),
    );

    expect(status, SubstitutionParticipantStatus.sick);
  });

  test('removed status overrides calendar vacation', () {
    final status = resolver.resolve(
      participant: _participant(status: SubstitutionParticipantStatus.removed),
      vacationPeriods: [
        _vacation(start: DateTime(2026, 9, 20), end: DateTime(2026, 9, 30)),
      ],
      date: DateTime(2026, 9, 24),
    );

    expect(status, SubstitutionParticipantStatus.removed);
  });

  test('keeps legacy vacation status without calendar period', () {
    final status = resolver.resolve(
      participant: _participant(status: SubstitutionParticipantStatus.vacation),
      vacationPeriods: const [],
      date: DateTime(2026, 9, 24),
    );

    expect(status, SubstitutionParticipantStatus.vacation);
  });
}

SubstitutionParticipant _participant({
  SubstitutionParticipantStatus status = SubstitutionParticipantStatus.active,
}) {
  return SubstitutionParticipant(
    userId: 'user-1',
    rotationOrder: 0,
    status: status,
  );
}

VacationPeriod _vacation({required DateTime start, required DateTime end}) {
  return VacationPeriod(
    userId: 'user-1',
    slot: 1,
    startDate: start,
    endDate: end,
  );
}
