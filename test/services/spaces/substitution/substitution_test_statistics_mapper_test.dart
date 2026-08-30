import 'package:epistola/services/spaces/substitution/substitution_test_statistics_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps valid aggregate statistics document', () {
    final statistics = SubstitutionTestStatisticsMapper.fromMap(
      <String, dynamic>{
        'callCounts': <String, dynamic>{'user-1': 7, 'user-2': 3},
      },
    );

    expect(statistics, isNotNull);
    expect(statistics!.callsFor('user-1'), 7);
    expect(statistics.callsFor('user-2'), 3);
  });

  test('maps empty callCounts', () {
    final statistics = SubstitutionTestStatisticsMapper.fromMap(
      <String, dynamic>{'callCounts': <String, dynamic>{}},
    );

    expect(statistics, isNotNull);
    expect(statistics!.isEmpty, isTrue);
  });

  test('rejects missing callCounts', () {
    final statistics = SubstitutionTestStatisticsMapper.fromMap(
      <String, dynamic>{},
    );

    expect(statistics, isNull);
  });

  test('rejects negative call count', () {
    final statistics = SubstitutionTestStatisticsMapper.fromMap(
      <String, dynamic>{
        'callCounts': <String, dynamic>{'user-1': -1},
      },
    );

    expect(statistics, isNull);
  });

  test('rejects non-integer call count', () {
    final statistics = SubstitutionTestStatisticsMapper.fromMap(
      <String, dynamic>{
        'callCounts': <String, dynamic>{'user-1': '7'},
      },
    );

    expect(statistics, isNull);
  });

  test('rejects invalid user id', () {
    final statistics = SubstitutionTestStatisticsMapper.fromMap(
      <String, dynamic>{
        'callCounts': <String, dynamic>{' user-1 ': 7},
      },
    );

    expect(statistics, isNull);
  });

  test('rejects user id containing slash', () {
    final statistics = SubstitutionTestStatisticsMapper.fromMap(
      <String, dynamic>{
        'callCounts': <String, dynamic>{'users/user-1': 7},
      },
    );

    expect(statistics, isNull);
  });
}
