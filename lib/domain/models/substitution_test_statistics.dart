final class SubstitutionTestStatistics {
  SubstitutionTestStatistics({
    Map<String, int> callCounts = const <String, int>{},
  }) : callCounts = Map<String, int>.unmodifiable(callCounts);

  final Map<String, int> callCounts;

  int callsFor(String userId) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return 0;
    }

    return callCounts[normalizedUserId] ?? 0;
  }

  bool get isEmpty => callCounts.isEmpty;
}
