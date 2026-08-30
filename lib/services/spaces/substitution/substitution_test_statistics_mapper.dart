import '../../../domain/models/substitution_test_statistics.dart';

final class SubstitutionTestStatisticsMapper {
  const SubstitutionTestStatisticsMapper._();

  static const String callCountsField = 'callCounts';

  static SubstitutionTestStatistics? fromMap(Map<String, dynamic> data) {
    final rawCallCounts = data[callCountsField];

    if (rawCallCounts is! Map) {
      return null;
    }

    final callCounts = <String, int>{};

    for (final entry in rawCallCounts.entries) {
      final rawUserId = entry.key;
      final rawCount = entry.value;

      if (rawUserId is! String) {
        return null;
      }

      final normalizedUserId = rawUserId.trim();

      if (normalizedUserId.isEmpty ||
          normalizedUserId != rawUserId ||
          normalizedUserId.contains('/')) {
        return null;
      }

      if (rawCount is! int || rawCount < 0) {
        return null;
      }

      callCounts[normalizedUserId] = rawCount;
    }

    return SubstitutionTestStatistics(callCounts: callCounts);
  }
}
