import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/domain/models/substitution_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubstitutionStatistics', () {
    final statistics = SubstitutionStatistics(
      year: 2026,
      monthCallCounts: <int, Map<String, int>>{
        8: <String, int>{'user-1': 3, 'user-2': 1},
        9: <String, int>{'user-1': 2},
      },
      monthShifts: <int, Map<String, List<SubstitutionShiftKind>>>{
        8: <String, List<SubstitutionShiftKind>>{
          'user-1': <SubstitutionShiftKind>[
            SubstitutionShiftKind.day,
            SubstitutionShiftKind.night,
            SubstitutionShiftKind.day,
          ],
          'user-2': <SubstitutionShiftKind>[SubstitutionShiftKind.night],
        },
        9: <String, List<SubstitutionShiftKind>>{
          'user-1': <SubstitutionShiftKind>[
            SubstitutionShiftKind.night,
            SubstitutionShiftKind.day,
          ],
        },
      },
      yearCallCounts: <String, int>{'user-1': 5, 'user-2': 1},
      lastFinalizedCallId: '123',
      updatedAt: DateTime.utc(2026, 9, 2, 10),
    );

    test('returns monthly call count', () {
      expect(statistics.callsForMonth(month: 8, userId: 'user-1'), 3);
    });

    test('returns ordered monthly shifts', () {
      expect(
        statistics.shiftsForMonth(month: 8, userId: 'user-1'),
        <SubstitutionShiftKind>[
          SubstitutionShiftKind.day,
          SubstitutionShiftKind.night,
          SubstitutionShiftKind.day,
        ],
      );
    });

    test('returns yearly call count', () {
      expect(statistics.callsForYear('user-1'), 5);
    });

    test('returns zero and empty shifts for missing user', () {
      expect(statistics.callsForMonth(month: 8, userId: 'missing'), 0);
      expect(statistics.shiftsForMonth(month: 8, userId: 'missing'), isEmpty);
      expect(statistics.callsForYear('missing'), 0);
    });

    test('nested collections are immutable', () {
      expect(
        () => statistics.monthCallCounts[8]!['user-1'] = 99,
        throwsUnsupportedError,
      );

      expect(
        () => statistics.monthShifts[8]!['user-1']!.add(
          SubstitutionShiftKind.night,
        ),
        throwsUnsupportedError,
      );

      expect(
        () => statistics.yearCallCounts['user-1'] = 99,
        throwsUnsupportedError,
      );
    });
  });
}
