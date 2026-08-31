import 'package:epistola/domain/models/substitution_pending_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/domain/models/substitution_statistics.dart';
import 'package:epistola/services/spaces/substitution/substitution_statistics_accumulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SubstitutionPendingCall pendingCall({
    required int revision,
    required int year,
    required int month,
    required int day,
    required SubstitutionShiftKind kind,
    String userId = 'user-1',
    DateTime? calledAt,
  }) {
    return SubstitutionPendingCall(
      callId: revision.toString(),
      userId: userId,
      revision: revision,
      calledByUserId: 'brigadier-1',
      calledAt: calledAt ?? DateTime.utc(2026, 8, 31, 10),
      shift: SubstitutionShift(year: year, month: month, day: day, kind: kind),
    );
  }

  SubstitutionStatistics existingStatistics() {
    return SubstitutionStatistics(
      year: 2026,
      monthCallCounts: <int, Map<String, int>>{
        8: <String, int>{'user-1': 1},
      },
      monthShifts: <int, Map<String, List<SubstitutionShiftKind>>>{
        8: <String, List<SubstitutionShiftKind>>{
          'user-1': <SubstitutionShiftKind>[SubstitutionShiftKind.day],
        },
      },
      yearCallCounts: <String, int>{'user-1': 1},
      lastFinalizedCallId: '1',
      updatedAt: DateTime.utc(2026, 8, 20),
    );
  }

  group('SubstitutionStatisticsAccumulator', () {
    test('creates first annual aggregate from confirmed call', () {
      final result = SubstitutionStatisticsAccumulator.applyConfirmedCall(
        current: null,
        pendingCall: pendingCall(
          revision: 1,
          year: 2026,
          month: 8,
          day: 31,
          kind: SubstitutionShiftKind.day,
        ),
      );

      expect(result.year, 2026);
      expect(result.monthCallCounts[8]!['user-1'], 1);
      expect(result.monthShifts[8]!['user-1'], <SubstitutionShiftKind>[
        SubstitutionShiftKind.day,
      ]);
      expect(result.yearCallCounts['user-1'], 1);
      expect(result.finalizedCallId, '1');
    });

    test('adds night shift to existing month', () {
      final result = SubstitutionStatisticsAccumulator.applyConfirmedCall(
        current: existingStatistics(),
        pendingCall: pendingCall(
          revision: 2,
          year: 2026,
          month: 8,
          day: 31,
          kind: SubstitutionShiftKind.night,
        ),
      );

      expect(result.monthCallCounts[8]!['user-1'], 2);
      expect(result.monthShifts[8]!['user-1'], <SubstitutionShiftKind>[
        SubstitutionShiftKind.day,
        SubstitutionShiftKind.night,
      ]);
      expect(result.yearCallCounts['user-1'], 2);
      expect(result.finalizedCallId, '2');
    });

    test('starts new month without removing previous month', () {
      final result = SubstitutionStatisticsAccumulator.applyConfirmedCall(
        current: existingStatistics(),
        pendingCall: pendingCall(
          revision: 2,
          year: 2026,
          month: 9,
          day: 1,
          kind: SubstitutionShiftKind.day,
        ),
      );

      expect(result.monthCallCounts[8]!['user-1'], 1);
      expect(result.monthCallCounts[9]!['user-1'], 1);

      expect(result.monthShifts[8]!['user-1'], <SubstitutionShiftKind>[
        SubstitutionShiftKind.day,
      ]);

      expect(result.monthShifts[9]!['user-1'], <SubstitutionShiftKind>[
        SubstitutionShiftKind.day,
      ]);

      expect(result.yearCallCounts['user-1'], 2);
    });

    test('adds another participant independently', () {
      final result = SubstitutionStatisticsAccumulator.applyConfirmedCall(
        current: existingStatistics(),
        pendingCall: pendingCall(
          revision: 2,
          year: 2026,
          month: 8,
          day: 31,
          kind: SubstitutionShiftKind.night,
          userId: 'user-2',
        ),
      );

      expect(result.monthCallCounts[8]!['user-1'], 1);
      expect(result.monthCallCounts[8]!['user-2'], 1);

      expect(result.monthShifts[8]!['user-2'], <SubstitutionShiftKind>[
        SubstitutionShiftKind.night,
      ]);

      expect(result.yearCallCounts['user-1'], 1);
      expect(result.yearCallCounts['user-2'], 1);
    });

    test('night shift is counted by shift start month, not calledAt month', () {
      final result = SubstitutionStatisticsAccumulator.applyConfirmedCall(
        current: existingStatistics(),
        pendingCall: pendingCall(
          revision: 2,
          year: 2026,
          month: 8,
          day: 31,
          kind: SubstitutionShiftKind.night,
          calledAt: DateTime.utc(2026, 9, 1, 0, 1),
        ),
      );

      expect(result.monthCallCounts[8]!['user-1'], 2);
      expect(result.monthCallCounts.containsKey(9), isFalse);

      expect(
        result.monthShifts[8]!['user-1']!.last,
        SubstitutionShiftKind.night,
      );
    });

    test('does not mutate current statistics', () {
      final current = existingStatistics();

      SubstitutionStatisticsAccumulator.applyConfirmedCall(
        current: current,
        pendingCall: pendingCall(
          revision: 2,
          year: 2026,
          month: 8,
          day: 31,
          kind: SubstitutionShiftKind.night,
        ),
      );

      expect(current.monthCallCounts[8]!['user-1'], 1);

      expect(current.monthShifts[8]!['user-1'], <SubstitutionShiftKind>[
        SubstitutionShiftKind.day,
      ]);

      expect(current.yearCallCounts['user-1'], 1);
    });

    test('rejects statistics from another year', () {
      expect(
        () => SubstitutionStatisticsAccumulator.applyConfirmedCall(
          current: existingStatistics(),
          pendingCall: pendingCall(
            revision: 2,
            year: 2027,
            month: 1,
            day: 1,
            kind: SubstitutionShiftKind.day,
          ),
        ),
        throwsStateError,
      );
    });

    test('rejects immediately repeated finalized call', () {
      expect(
        () => SubstitutionStatisticsAccumulator.applyConfirmedCall(
          current: existingStatistics(),
          pendingCall: pendingCall(
            revision: 1,
            year: 2026,
            month: 8,
            day: 20,
            kind: SubstitutionShiftKind.day,
          ),
        ),
        throwsStateError,
      );
    });
  });
}
