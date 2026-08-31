import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/substitution/substitution_statistics_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing yearly document returns null with one read', () async {
    var readCount = 0;
    int? requestedYear;

    final gateway = SubstitutionStatisticsFirestoreGateway(
      documentReader: ({required int year}) async {
        readCount += 1;
        requestedYear = year;

        return null;
      },
    );

    final statistics = await gateway.load(year: 2026);

    expect(statistics, isNull);
    expect(readCount, 1);
    expect(requestedYear, 2026);
  });

  test('loads yearly aggregate with one document read', () async {
    var readCount = 0;

    final gateway = SubstitutionStatisticsFirestoreGateway(
      documentReader: ({required int year}) async {
        readCount += 1;

        return _validStatisticsData(year: year);
      },
    );

    final statistics = await gateway.load(year: 2026);

    expect(readCount, 1);
    expect(statistics, isNotNull);

    expect(statistics!.callsForMonth(month: 8, userId: 'user-1'), 2);

    expect(
      statistics.shiftsForMonth(month: 8, userId: 'user-1'),
      <SubstitutionShiftKind>[
        SubstitutionShiftKind.day,
        SubstitutionShiftKind.night,
      ],
    );

    expect(statistics.callsForYear('user-1'), 2);
  });

  test('rejects document for another year', () async {
    final gateway = SubstitutionStatisticsFirestoreGateway(
      documentReader: ({required int year}) async {
        return _validStatisticsData(year: 2025);
      },
    );

    await expectLater(gateway.load(year: 2026), throwsStateError);
  });

  test('rejects invalid requested year before read', () async {
    var readCount = 0;

    final gateway = SubstitutionStatisticsFirestoreGateway(
      documentReader: ({required int year}) async {
        readCount += 1;

        return null;
      },
    );

    await expectLater(gateway.load(year: 0), throwsArgumentError);

    expect(readCount, 0);
  });
}

Map<String, dynamic> _validStatisticsData({required int year}) {
  return <String, dynamic>{
    'year': year,
    'monthCallCounts': <String, dynamic>{
      '8': <String, dynamic>{'user-1': 2},
    },
    'monthShifts': <String, dynamic>{
      '8': <String, dynamic>{
        'user-1': <String>['day', 'night'],
      },
    },
    'yearCallCounts': <String, dynamic>{'user-1': 2},
    'lastFinalizedCallId': '2',
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 31, 12)),
  };
}
