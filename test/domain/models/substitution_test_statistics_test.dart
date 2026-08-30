import 'package:epistola/domain/models/substitution_test_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns zero for user without calls', () {
    final statistics = SubstitutionTestStatistics();

    expect(statistics.callsFor('user-1'), 0);
  });

  test('returns stored call count', () {
    final statistics = SubstitutionTestStatistics(
      callCounts: <String, int>{'user-1': 7, 'user-2': 3},
    );

    expect(statistics.callsFor('user-1'), 7);
    expect(statistics.callsFor('user-2'), 3);
  });

  test('normalizes user id before lookup', () {
    final statistics = SubstitutionTestStatistics(
      callCounts: <String, int>{'user-1': 4},
    );

    expect(statistics.callsFor('  user-1  '), 4);
  });

  test('does not expose mutable call counts', () {
    final source = <String, int>{'user-1': 2};

    final statistics = SubstitutionTestStatistics(callCounts: source);

    source['user-1'] = 99;

    expect(statistics.callsFor('user-1'), 2);
    expect(() => statistics.callCounts['user-1'] = 5, throwsUnsupportedError);
  });
}
