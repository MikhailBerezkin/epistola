import 'substitution_shift.dart';

final class SubstitutionStatistics {
  SubstitutionStatistics({
    required this.year,
    required Map<int, Map<String, int>> monthCallCounts,
    required Map<int, Map<String, List<SubstitutionShiftKind>>> monthShifts,
    required Map<String, int> yearCallCounts,
    required this.lastFinalizedCallId,
    required this.updatedAt,
  }) : monthCallCounts = _freezeMonthCallCounts(monthCallCounts),
       monthShifts = _freezeMonthShifts(monthShifts),
       yearCallCounts = Map<String, int>.unmodifiable(yearCallCounts);

  final int year;

  /// Количество подтверждённых вызовов по месяцам.
  ///
  /// Ключ первого уровня: номер месяца 1..12.
  /// Ключ второго уровня: UID участника.
  final Map<int, Map<String, int>> monthCallCounts;

  /// Хронологическая последовательность подтверждённых смен по месяцам.
  ///
  /// Используется для будущей графической шкалы:
  /// day   -> дневной цвет;
  /// night -> ночной цвет.
  final Map<int, Map<String, List<SubstitutionShiftKind>>> monthShifts;

  /// Суммарное количество подтверждённых вызовов за год по UID.
  final Map<String, int> yearCallCounts;

  /// Последний callId, применённый к этому агрегату.
  ///
  /// Техническое поле. В UI не показывается.
  final String lastFinalizedCallId;

  /// Серверное время последнего изменения агрегата.
  final DateTime updatedAt;

  int callsForMonth({required int month, required String userId}) {
    final normalizedUserId = userId.trim();

    if (month < 1 ||
        month > 12 ||
        normalizedUserId.isEmpty ||
        normalizedUserId.contains('/')) {
      return 0;
    }

    return monthCallCounts[month]?[normalizedUserId] ?? 0;
  }

  List<SubstitutionShiftKind> shiftsForMonth({
    required int month,
    required String userId,
  }) {
    final normalizedUserId = userId.trim();

    if (month < 1 ||
        month > 12 ||
        normalizedUserId.isEmpty ||
        normalizedUserId.contains('/')) {
      return const <SubstitutionShiftKind>[];
    }

    return monthShifts[month]?[normalizedUserId] ??
        const <SubstitutionShiftKind>[];
  }

  int callsForYear(String userId) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty || normalizedUserId.contains('/')) {
      return 0;
    }

    return yearCallCounts[normalizedUserId] ?? 0;
  }

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
