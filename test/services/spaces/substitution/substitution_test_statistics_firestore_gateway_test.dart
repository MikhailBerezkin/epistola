import 'package:epistola/services/spaces/substitution/substitution_test_statistics_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing document returns empty statistics', () async {
    var readCount = 0;

    final gateway = SubstitutionTestStatisticsFirestoreGateway(
      documentReader: () async {
        readCount += 1;
        return null;
      },
    );

    final statistics = await gateway.load();

    expect(readCount, 1);
    expect(statistics.isEmpty, isTrue);
    expect(statistics.callsFor('user-1'), 0);
  });

  test('loads aggregate statistics with one document read', () async {
    var readCount = 0;

    final gateway = SubstitutionTestStatisticsFirestoreGateway(
      documentReader: () async {
        readCount += 1;

        return <String, dynamic>{
          'callCounts': <String, dynamic>{'user-1': 7, 'user-2': 3},
        };
      },
    );

    final statistics = await gateway.load();

    expect(readCount, 1);
    expect(statistics.callsFor('user-1'), 7);
    expect(statistics.callsFor('user-2'), 3);
  });

  test('invalid document throws state error', () async {
    final gateway = SubstitutionTestStatisticsFirestoreGateway(
      documentReader: () async {
        return <String, dynamic>{
          'callCounts': <String, dynamic>{'user-1': -1},
        };
      },
    );

    expect(gateway.load, throwsA(isA<StateError>()));
  });
}
