import 'package:epistola/domain/models/substitution_test_statistics.dart';
import 'package:epistola/services/spaces/substitution/substitution_test_statistics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads statistics through injected loader', () async {
    var loadCount = 0;

    final service = SubstitutionTestStatisticsService(
      statisticsLoader: () async {
        loadCount += 1;

        return SubstitutionTestStatistics(
          callCounts: <String, int>{'user-1': 7},
        );
      },
    );

    final statistics = await service.load();

    expect(loadCount, 1);
    expect(statistics.callsFor('user-1'), 7);
  });

  test('propagates loader error', () async {
    final service = SubstitutionTestStatisticsService(
      statisticsLoader: () async {
        throw StateError('broken statistics');
      },
    );

    expect(service.load, throwsA(isA<StateError>()));
  });
}
