import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/substitution/substitution_statistics_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> validData() {
    return <String, dynamic>{
      'year': 2026,
      'monthCallCounts': <String, dynamic>{
        '8': <String, dynamic>{'user-1': 3, 'user-2': 1},
        '9': <String, dynamic>{'user-1': 2},
      },
      'monthShifts': <String, dynamic>{
        '8': <String, dynamic>{
          'user-1': <dynamic>['day', 'night', 'day'],
          'user-2': <dynamic>['night'],
        },
        '9': <String, dynamic>{
          'user-1': <dynamic>['night', 'day'],
        },
      },
      'yearCallCounts': <String, dynamic>{'user-1': 5, 'user-2': 1},
      'lastFinalizedCallId': '123',
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 2, 10)),
    };
  }

  test('maps valid production statistics document', () {
    final statistics = SubstitutionStatisticsMapper.fromMap(
      validData(),
      expectedYear: 2026,
    );

    expect(statistics, isNotNull);
    expect(statistics!.year, 2026);
    expect(statistics.callsForMonth(month: 8, userId: 'user-1'), 3);
    expect(
      statistics.shiftsForMonth(month: 8, userId: 'user-1'),
      <SubstitutionShiftKind>[
        SubstitutionShiftKind.day,
        SubstitutionShiftKind.night,
        SubstitutionShiftKind.day,
      ],
    );
    expect(statistics.callsForYear('user-1'), 5);
    expect(statistics.lastFinalizedCallId, '123');
    expect(statistics.updatedAt.isUtc, isTrue);
  });

  test('rejects unexpected field', () {
    final data = validData()..['unexpected'] = true;

    expect(SubstitutionStatisticsMapper.fromMap(data), isNull);
  });

  test('rejects mismatched expected year', () {
    expect(
      SubstitutionStatisticsMapper.fromMap(validData(), expectedYear: 2027),
      isNull,
    );
  });

  test('rejects invalid month key', () {
    final data = validData();

    data['monthCallCounts'] = <String, dynamic>{
      '08': <String, dynamic>{'user-1': 3},
    };

    expect(SubstitutionStatisticsMapper.fromMap(data), isNull);
  });

  test('rejects invalid shift kind', () {
    final data = validData();

    final monthShifts = data['monthShifts'] as Map<String, dynamic>;
    final august = monthShifts['8'] as Map<String, dynamic>;

    august['user-1'] = <dynamic>['day', 'evening', 'day'];

    expect(SubstitutionStatisticsMapper.fromMap(data), isNull);
  });

  test('rejects monthly count that differs from shift history', () {
    final data = validData();

    final monthCounts = data['monthCallCounts'] as Map<String, dynamic>;
    final august = monthCounts['8'] as Map<String, dynamic>;

    august['user-1'] = 4;

    expect(SubstitutionStatisticsMapper.fromMap(data), isNull);
  });

  test('rejects yearly count that differs from month totals', () {
    final data = validData();

    final yearCounts = data['yearCallCounts'] as Map<String, dynamic>;

    yearCounts['user-1'] = 6;

    expect(SubstitutionStatisticsMapper.fromMap(data), isNull);
  });

  test('rejects invalid call id', () {
    final data = validData()..['lastFinalizedCallId'] = '0123';

    expect(SubstitutionStatisticsMapper.fromMap(data), isNull);
  });

  test('rejects invalid user id', () {
    final data = validData();

    data['yearCallCounts'] = <String, dynamic>{' user-1 ': 5, 'user-2': 1};

    expect(SubstitutionStatisticsMapper.fromMap(data), isNull);
  });

  test('writes valid production statistics document', () {
    final data = SubstitutionStatisticsMapper.toWriteMap(
      year: 2026,
      monthCallCounts: <int, Map<String, int>>{
        8: <String, int>{'user-1': 2},
        9: <String, int>{'user-1': 1},
      },
      monthShifts: <int, Map<String, List<SubstitutionShiftKind>>>{
        8: <String, List<SubstitutionShiftKind>>{
          'user-1': <SubstitutionShiftKind>[
            SubstitutionShiftKind.day,
            SubstitutionShiftKind.night,
          ],
        },
        9: <String, List<SubstitutionShiftKind>>{
          'user-1': <SubstitutionShiftKind>[SubstitutionShiftKind.day],
        },
      },
      yearCallCounts: <String, int>{'user-1': 3},
      finalizedCallId: '123',
    );

    expect(data['year'], 2026);

    expect(data['monthCallCounts'], <String, dynamic>{
      '8': <String, dynamic>{'user-1': 2},
      '9': <String, dynamic>{'user-1': 1},
    });

    expect(data['monthShifts'], <String, dynamic>{
      '8': <String, dynamic>{
        'user-1': <String>['day', 'night'],
      },
      '9': <String, dynamic>{
        'user-1': <String>['day'],
      },
    });

    expect(data['yearCallCounts'], <String, dynamic>{'user-1': 3});

    expect(data['lastFinalizedCallId'], '123');
    expect(data['updatedAt'], isA<FieldValue>());
  });

  test('write mapper rejects inconsistent shift history', () {
    expect(
      () => SubstitutionStatisticsMapper.toWriteMap(
        year: 2026,
        monthCallCounts: <int, Map<String, int>>{
          8: <String, int>{'user-1': 2},
        },
        monthShifts: <int, Map<String, List<SubstitutionShiftKind>>>{
          8: <String, List<SubstitutionShiftKind>>{
            'user-1': <SubstitutionShiftKind>[SubstitutionShiftKind.day],
          },
        },
        yearCallCounts: <String, int>{'user-1': 2},
        finalizedCallId: '123',
      ),
      throwsStateError,
    );
  });

  test('write mapper rejects inconsistent yearly total', () {
    expect(
      () => SubstitutionStatisticsMapper.toWriteMap(
        year: 2026,
        monthCallCounts: <int, Map<String, int>>{
          8: <String, int>{'user-1': 1},
        },
        monthShifts: <int, Map<String, List<SubstitutionShiftKind>>>{
          8: <String, List<SubstitutionShiftKind>>{
            'user-1': <SubstitutionShiftKind>[SubstitutionShiftKind.night],
          },
        },
        yearCallCounts: <String, int>{'user-1': 2},
        finalizedCallId: '123',
      ),
      throwsStateError,
    );
  });
}
