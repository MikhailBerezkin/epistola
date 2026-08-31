import '../../../domain/models/substitution_pending_call.dart';
import '../../../domain/models/substitution_shift.dart';
import '../../../domain/models/substitution_statistics.dart';

final class SubstitutionStatisticsMutation {
  SubstitutionStatisticsMutation({
    required this.year,
    required Map<int, Map<String, int>> monthCallCounts,
    required Map<int, Map<String, List<SubstitutionShiftKind>>> monthShifts,
    required Map<String, int> yearCallCounts,
    required this.finalizedCallId,
  }) : monthCallCounts = _freezeMonthCallCounts(monthCallCounts),
       monthShifts = _freezeMonthShifts(monthShifts),
       yearCallCounts = Map<String, int>.unmodifiable(yearCallCounts);

  final int year;

  final Map<int, Map<String, int>> monthCallCounts;

  final Map<int, Map<String, List<SubstitutionShiftKind>>> monthShifts;

  final Map<String, int> yearCallCounts;

  /// Call, который должен быть связан с этой записью статистики
  /// в будущей Firestore transaction.
  final String finalizedCallId;

  static Map<int, Map<String, int>> _freezeMonthCallCounts(
    Map<int, Map<String, int>> source,
  ) {
    final result = <int, Map<String, int>>{};

    for (final entry in source.entries) {
      result[entry.key] = Map<String, int>.unmodifiable(entry.value);
    }

    return Map<int, Map<String, int>>.unmodifiable(result);
  }

  static Map<int, Map<String, List<SubstitutionShiftKind>>> _freezeMonthShifts(
    Map<int, Map<String, List<SubstitutionShiftKind>>> source,
  ) {
    final result = <int, Map<String, List<SubstitutionShiftKind>>>{};

    for (final monthEntry in source.entries) {
      final users = <String, List<SubstitutionShiftKind>>{};

      for (final userEntry in monthEntry.value.entries) {
        users[userEntry.key] = List<SubstitutionShiftKind>.unmodifiable(
          userEntry.value,
        );
      }

      result[monthEntry.key] =
          Map<String, List<SubstitutionShiftKind>>.unmodifiable(users);
    }

    return Map<int, Map<String, List<SubstitutionShiftKind>>>.unmodifiable(
      result,
    );
  }
}

final class SubstitutionStatisticsAccumulator {
  const SubstitutionStatisticsAccumulator._();

  static SubstitutionStatisticsMutation applyConfirmedCall({
    required SubstitutionStatistics? current,
    required SubstitutionPendingCall pendingCall,
  }) {
    _validatePendingCall(pendingCall);

    final statisticsYear = pendingCall.shift.statisticsYear;
    final statisticsMonth = pendingCall.shift.statisticsMonth;

    if (current != null && current.year != statisticsYear) {
      throw StateError(
        'Statistics year ${current.year} does not match '
        'pending call year $statisticsYear.',
      );
    }

    if (current != null && current.lastFinalizedCallId == pendingCall.callId) {
      throw StateError(
        'Pending call ${pendingCall.callId} was already applied '
        'to this statistics snapshot.',
      );
    }

    final monthCallCounts = _copyMonthCallCounts(current?.monthCallCounts);

    final monthShifts = _copyMonthShifts(current?.monthShifts);

    final yearCallCounts = <String, int>{...?current?.yearCallCounts};

    final userId = pendingCall.userId;

    final monthCounts = monthCallCounts.putIfAbsent(
      statisticsMonth,
      () => <String, int>{},
    );

    final monthShiftUsers = monthShifts.putIfAbsent(
      statisticsMonth,
      () => <String, List<SubstitutionShiftKind>>{},
    );

    monthCounts.update(userId, (value) => value + 1, ifAbsent: () => 1);

    monthShiftUsers
        .putIfAbsent(userId, () => <SubstitutionShiftKind>[])
        .add(pendingCall.shift.kind);

    yearCallCounts.update(userId, (value) => value + 1, ifAbsent: () => 1);

    return SubstitutionStatisticsMutation(
      year: statisticsYear,
      monthCallCounts: monthCallCounts,
      monthShifts: monthShifts,
      yearCallCounts: yearCallCounts,
      finalizedCallId: pendingCall.callId,
    );
  }

  static Map<int, Map<String, int>> _copyMonthCallCounts(
    Map<int, Map<String, int>>? source,
  ) {
    if (source == null) {
      return <int, Map<String, int>>{};
    }

    return <int, Map<String, int>>{
      for (final entry in source.entries)
        entry.key: <String, int>{...entry.value},
    };
  }

  static Map<int, Map<String, List<SubstitutionShiftKind>>> _copyMonthShifts(
    Map<int, Map<String, List<SubstitutionShiftKind>>>? source,
  ) {
    if (source == null) {
      return <int, Map<String, List<SubstitutionShiftKind>>>{};
    }

    return <int, Map<String, List<SubstitutionShiftKind>>>{
      for (final monthEntry in source.entries)
        monthEntry.key: <String, List<SubstitutionShiftKind>>{
          for (final userEntry in monthEntry.value.entries)
            userEntry.key: <SubstitutionShiftKind>[...userEntry.value],
        },
    };
  }

  static void _validatePendingCall(SubstitutionPendingCall pendingCall) {
    final userId = pendingCall.userId.trim();

    if (userId.isEmpty ||
        userId != pendingCall.userId ||
        userId.contains('/')) {
      throw StateError('Pending call contains invalid userId.');
    }

    if (pendingCall.revision < 1 ||
        pendingCall.callId != pendingCall.revision.toString()) {
      throw StateError('Pending call contains invalid call identity.');
    }
  }
}
