import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/domain/models/vacation_period.dart';
import 'package:epistola/services/spaces/substitution/substitution_call_eligibility_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = SubstitutionCallEligibilityResolver();

  group('schedule eligibility', () {
    final cases =
        <({String name, DateTime date, bool dayAllowed, bool nightAllowed})>[
          (
            name: 'day1',
            date: DateTime.utc(2026, 9, 13),
            dayAllowed: false,
            nightAllowed: false,
          ),
          (
            name: 'day2',
            date: DateTime.utc(2026, 9, 14),
            dayAllowed: false,
            nightAllowed: false,
          ),
          (
            name: 'offBeforeNight',
            date: DateTime.utc(2026, 9, 15),
            dayAllowed: true,
            nightAllowed: true,
          ),
          (
            name: 'night1',
            date: DateTime.utc(2026, 9, 16),
            dayAllowed: false,
            nightAllowed: false,
          ),
          (
            name: 'night2',
            date: DateTime.utc(2026, 9, 17),
            dayAllowed: false,
            nightAllowed: false,
          ),
          (
            name: 'recovery',
            date: DateTime.utc(2026, 9, 18),
            dayAllowed: false,
            nightAllowed: true,
          ),
          (
            name: 'offAfterRecovery1',
            date: DateTime.utc(2026, 9, 19),
            dayAllowed: true,
            nightAllowed: true,
          ),
          (
            name: 'offAfterRecovery2',
            date: DateTime.utc(2026, 9, 20),
            dayAllowed: true,
            nightAllowed: false,
          ),
        ];

    for (final testCase in cases) {
      test('${testCase.name} day eligibility', () {
        final result = resolver.resolve(
          userId: 'user-1',
          crew: ShiftCrew.crew4,
          shift: _shift(date: testCase.date, kind: SubstitutionShiftKind.day),
          vacationPeriods: const <VacationPeriod>[],
        );

        expect(result.isEligible, testCase.dayAllowed);

        expect(
          result.reason,
          testCase.dayAllowed
              ? isNull
              : SubstitutionCallIneligibilityReason.workShift,
        );
      });

      test('${testCase.name} night eligibility', () {
        final result = resolver.resolve(
          userId: 'user-1',
          crew: ShiftCrew.crew4,
          shift: _shift(date: testCase.date, kind: SubstitutionShiftKind.night),
          vacationPeriods: const <VacationPeriod>[],
        );

        expect(result.isEligible, testCase.nightAllowed);

        expect(
          result.reason,
          testCase.nightAllowed
              ? isNull
              : SubstitutionCallIneligibilityReason.workShift,
        );
      });
    }
  });

  test('rejects participant without assigned crew', () {
    final result = resolver.resolve(
      userId: 'user-1',
      crew: null,
      shift: _shift(
        date: DateTime.utc(2026, 9, 15),
        kind: SubstitutionShiftKind.day,
      ),
      vacationPeriods: const <VacationPeriod>[],
    );

    expect(result.isEligible, isFalse);
    expect(result.reason, SubstitutionCallIneligibilityReason.missingCrew);
  });

  test('day shift is unavailable when its date is in vacation', () {
    final result = resolver.resolve(
      userId: 'user-1',
      crew: ShiftCrew.crew4,
      shift: _shift(
        date: DateTime.utc(2026, 9, 15),
        kind: SubstitutionShiftKind.day,
      ),
      vacationPeriods: <VacationPeriod>[
        _vacation(
          userId: 'user-1',
          start: DateTime.utc(2026, 9, 15),
          end: DateTime.utc(2026, 9, 15),
        ),
      ],
    );

    expect(result.isEligible, isFalse);
    expect(result.reason, SubstitutionCallIneligibilityReason.vacation);
  });

  test('night shift is unavailable when start date is in vacation', () {
    final result = resolver.resolve(
      userId: 'user-1',
      crew: ShiftCrew.crew4,
      shift: _shift(
        date: DateTime.utc(2026, 9, 15),
        kind: SubstitutionShiftKind.night,
      ),
      vacationPeriods: <VacationPeriod>[
        _vacation(
          userId: 'user-1',
          start: DateTime.utc(2026, 9, 15),
          end: DateTime.utc(2026, 9, 15),
        ),
      ],
    );

    expect(result.isEligible, isFalse);
    expect(result.reason, SubstitutionCallIneligibilityReason.vacation);
  });

  test('night shift is unavailable when next date is in vacation', () {
    final result = resolver.resolve(
      userId: 'user-1',
      crew: ShiftCrew.crew4,
      shift: _shift(
        date: DateTime.utc(2026, 9, 15),
        kind: SubstitutionShiftKind.night,
      ),
      vacationPeriods: <VacationPeriod>[
        _vacation(
          userId: 'user-1',
          start: DateTime.utc(2026, 9, 16),
          end: DateTime.utc(2026, 9, 16),
        ),
      ],
    );

    expect(result.isEligible, isFalse);
    expect(result.reason, SubstitutionCallIneligibilityReason.vacation);
  });

  test('vacation of another participant does not block call', () {
    final result = resolver.resolve(
      userId: 'user-1',
      crew: ShiftCrew.crew4,
      shift: _shift(
        date: DateTime.utc(2026, 9, 15),
        kind: SubstitutionShiftKind.day,
      ),
      vacationPeriods: <VacationPeriod>[
        _vacation(
          userId: 'user-2',
          start: DateTime.utc(2026, 9, 15),
          end: DateTime.utc(2026, 9, 20),
        ),
      ],
    );

    expect(result.isEligible, isTrue);
    expect(result.reason, isNull);
  });

  test('non-overlapping vacation does not block call', () {
    final result = resolver.resolve(
      userId: 'user-1',
      crew: ShiftCrew.crew4,
      shift: _shift(
        date: DateTime.utc(2026, 9, 15),
        kind: SubstitutionShiftKind.day,
      ),
      vacationPeriods: <VacationPeriod>[
        _vacation(
          userId: 'user-1',
          start: DateTime.utc(2026, 10, 1),
          end: DateTime.utc(2026, 10, 5),
        ),
      ],
    );

    expect(result.isEligible, isTrue);
    expect(result.reason, isNull);
  });

  test('vacation takes priority over work-shift reason', () {
    final result = resolver.resolve(
      userId: 'user-1',
      crew: ShiftCrew.crew4,
      shift: _shift(
        date: DateTime.utc(2026, 9, 14),
        kind: SubstitutionShiftKind.day,
      ),
      vacationPeriods: <VacationPeriod>[
        _vacation(
          userId: 'user-1',
          start: DateTime.utc(2026, 9, 14),
          end: DateTime.utc(2026, 9, 14),
        ),
      ],
    );

    expect(result.isEligible, isFalse);
    expect(result.reason, SubstitutionCallIneligibilityReason.vacation);
  });

  test('rejects empty participant id', () {
    expect(
      () => resolver.resolve(
        userId: '   ',
        crew: ShiftCrew.crew4,
        shift: _shift(
          date: DateTime.utc(2026, 9, 15),
          kind: SubstitutionShiftKind.day,
        ),
        vacationPeriods: const <VacationPeriod>[],
      ),
      throwsArgumentError,
    );
  });
}

SubstitutionShift _shift({
  required DateTime date,
  required SubstitutionShiftKind kind,
}) {
  return SubstitutionShift(
    year: date.year,
    month: date.month,
    day: date.day,
    kind: kind,
  );
}

VacationPeriod _vacation({
  required String userId,
  required DateTime start,
  required DateTime end,
}) {
  return VacationPeriod(
    userId: userId,
    slot: 1,
    startDate: start,
    endDate: end,
  );
}
