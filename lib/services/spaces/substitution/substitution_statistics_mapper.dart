import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_shift.dart';
import '../../../domain/models/substitution_statistics.dart';

final class SubstitutionStatisticsMapper {
  const SubstitutionStatisticsMapper._();

  static const String yearField = 'year';
  static const String monthCallCountsField = 'monthCallCounts';
  static const String monthShiftsField = 'monthShifts';
  static const String yearCallCountsField = 'yearCallCounts';
  static const String lastFinalizedCallIdField = 'lastFinalizedCallId';
  static const String updatedAtField = 'updatedAt';

  static const Set<String> _allowedFields = <String>{
    yearField,
    monthCallCountsField,
    monthShiftsField,
    yearCallCountsField,
    lastFinalizedCallIdField,
    updatedAtField,
  };

  static SubstitutionStatistics? fromMap(
    Map<String, dynamic> data, {
    int? expectedYear,
  }) {
    if (data.length != _allowedFields.length ||
        !data.keys.every(_allowedFields.contains)) {
      return null;
    }

    final rawYear = data[yearField];
    final rawMonthCallCounts = data[monthCallCountsField];
    final rawMonthShifts = data[monthShiftsField];
    final rawYearCallCounts = data[yearCallCountsField];
    final rawLastFinalizedCallId = data[lastFinalizedCallIdField];
    final rawUpdatedAt = data[updatedAtField];

    if (rawYear is! int ||
        rawYear < 1 ||
        rawMonthCallCounts is! Map ||
        rawMonthShifts is! Map ||
        rawYearCallCounts is! Map ||
        rawLastFinalizedCallId is! String ||
        rawUpdatedAt is! Timestamp) {
      return null;
    }

    if (expectedYear != null && rawYear != expectedYear) {
      return null;
    }

    if (!_isValidCallId(rawLastFinalizedCallId)) {
      return null;
    }

    final monthCallCounts = _readMonthCallCounts(rawMonthCallCounts);

    if (monthCallCounts == null) {
      return null;
    }

    final monthShifts = _readMonthShifts(rawMonthShifts);

    if (monthShifts == null) {
      return null;
    }

    final yearCallCounts = _readCallCounts(rawYearCallCounts);

    if (yearCallCounts == null) {
      return null;
    }

    if (!_hasConsistentStatistics(
      monthCallCounts: monthCallCounts,
      monthShifts: monthShifts,
      yearCallCounts: yearCallCounts,
    )) {
      return null;
    }

    return SubstitutionStatistics(
      year: rawYear,
      monthCallCounts: monthCallCounts,
      monthShifts: monthShifts,
      yearCallCounts: yearCallCounts,
      lastFinalizedCallId: rawLastFinalizedCallId,
      updatedAt: rawUpdatedAt.toDate().toUtc(),
    );
  }

  static Map<String, dynamic> toWriteMap({
    required int year,
    required Map<int, Map<String, int>> monthCallCounts,
    required Map<int, Map<String, List<SubstitutionShiftKind>>> monthShifts,
    required Map<String, int> yearCallCounts,
    required String finalizedCallId,
  }) {
    if (year < 1) {
      throw ArgumentError.value(
        year,
        'year',
        'year must be greater than zero.',
      );
    }

    if (!_isValidCallId(finalizedCallId)) {
      throw ArgumentError.value(
        finalizedCallId,
        'finalizedCallId',
        'finalizedCallId must be a canonical positive integer string.',
      );
    }

    if (!_hasValidWriteData(
      monthCallCounts: monthCallCounts,
      monthShifts: monthShifts,
      yearCallCounts: yearCallCounts,
    )) {
      throw StateError('Statistics write data is inconsistent.');
    }

    return <String, dynamic>{
      yearField: year,
      monthCallCountsField: <String, dynamic>{
        for (final month in _sortedMonths(monthCallCounts.keys))
          month.toString(): <String, dynamic>{...monthCallCounts[month]!},
      },
      monthShiftsField: <String, dynamic>{
        for (final month in _sortedMonths(monthShifts.keys))
          month.toString(): <String, dynamic>{
            for (final entry in monthShifts[month]!.entries)
              entry.key: <String>[
                for (final shift in entry.value) _shiftKindToStorage(shift),
              ],
          },
      },
      yearCallCountsField: <String, dynamic>{...yearCallCounts},
      lastFinalizedCallIdField: finalizedCallId,
      updatedAtField: FieldValue.serverTimestamp(),
    };
  }

  static Map<int, Map<String, int>>? _readMonthCallCounts(Map rawData) {
    final result = <int, Map<String, int>>{};

    for (final entry in rawData.entries) {
      final month = _parseMonth(entry.key);
      final rawCounts = entry.value;

      if (month == null || rawCounts is! Map) {
        return null;
      }

      final counts = _readCallCounts(rawCounts);

      if (counts == null) {
        return null;
      }

      result[month] = counts;
    }

    return result;
  }

  static Map<int, Map<String, List<SubstitutionShiftKind>>>? _readMonthShifts(
    Map rawData,
  ) {
    final result = <int, Map<String, List<SubstitutionShiftKind>>>{};

    for (final monthEntry in rawData.entries) {
      final month = _parseMonth(monthEntry.key);
      final rawUsers = monthEntry.value;

      if (month == null || rawUsers is! Map) {
        return null;
      }

      final users = <String, List<SubstitutionShiftKind>>{};

      for (final userEntry in rawUsers.entries) {
        final rawUserId = userEntry.key;
        final rawShifts = userEntry.value;

        if (rawUserId is! String ||
            !_isValidUserId(rawUserId) ||
            rawShifts is! List) {
          return null;
        }

        final shifts = <SubstitutionShiftKind>[];

        for (final rawShift in rawShifts) {
          final shift = _shiftKindFromStorage(rawShift);

          if (shift == null) {
            return null;
          }

          shifts.add(shift);
        }

        users[rawUserId] = shifts;
      }

      result[month] = users;
    }

    return result;
  }

  static Map<String, int>? _readCallCounts(Map rawData) {
    final result = <String, int>{};

    for (final entry in rawData.entries) {
      final rawUserId = entry.key;
      final rawCount = entry.value;

      if (rawUserId is! String ||
          !_isValidUserId(rawUserId) ||
          rawCount is! int ||
          rawCount < 0) {
        return null;
      }

      result[rawUserId] = rawCount;
    }

    return result;
  }

  static bool _hasValidWriteData({
    required Map<int, Map<String, int>> monthCallCounts,
    required Map<int, Map<String, List<SubstitutionShiftKind>>> monthShifts,
    required Map<String, int> yearCallCounts,
  }) {
    for (final month in monthCallCounts.keys) {
      if (month < 1 || month > 12) {
        return false;
      }

      for (final entry in monthCallCounts[month]!.entries) {
        if (!_isValidUserId(entry.key) || entry.value < 0) {
          return false;
        }
      }
    }

    for (final month in monthShifts.keys) {
      if (month < 1 || month > 12) {
        return false;
      }

      for (final userId in monthShifts[month]!.keys) {
        if (!_isValidUserId(userId)) {
          return false;
        }
      }
    }

    for (final entry in yearCallCounts.entries) {
      if (!_isValidUserId(entry.key) || entry.value < 0) {
        return false;
      }
    }

    return _hasConsistentStatistics(
      monthCallCounts: monthCallCounts,
      monthShifts: monthShifts,
      yearCallCounts: yearCallCounts,
    );
  }

  static bool _hasConsistentStatistics({
    required Map<int, Map<String, int>> monthCallCounts,
    required Map<int, Map<String, List<SubstitutionShiftKind>>> monthShifts,
    required Map<String, int> yearCallCounts,
  }) {
    if (!_sameKeys(monthCallCounts.keys, monthShifts.keys)) {
      return false;
    }

    final calculatedYearCounts = <String, int>{};

    for (final monthEntry in monthCallCounts.entries) {
      final shiftUsers = monthShifts[monthEntry.key];

      if (shiftUsers == null ||
          !_sameKeys(monthEntry.value.keys, shiftUsers.keys)) {
        return false;
      }

      for (final userEntry in monthEntry.value.entries) {
        final shifts = shiftUsers[userEntry.key];

        if (shifts == null || shifts.length != userEntry.value) {
          return false;
        }

        calculatedYearCounts.update(
          userEntry.key,
          (value) => value + userEntry.value,
          ifAbsent: () => userEntry.value,
        );
      }
    }

    if (!_sameKeys(calculatedYearCounts.keys, yearCallCounts.keys)) {
      return false;
    }

    for (final entry in calculatedYearCounts.entries) {
      if (yearCallCounts[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }

  static int? _parseMonth(Object? value) {
    if (value is! String) {
      return null;
    }

    final month = int.tryParse(value);

    if (month == null || month < 1 || month > 12 || month.toString() != value) {
      return null;
    }

    return month;
  }

  static SubstitutionShiftKind? _shiftKindFromStorage(Object? value) {
    return switch (value) {
      'day' => SubstitutionShiftKind.day,
      'night' => SubstitutionShiftKind.night,
      _ => null,
    };
  }

  static String _shiftKindToStorage(SubstitutionShiftKind value) {
    return switch (value) {
      SubstitutionShiftKind.day => 'day',
      SubstitutionShiftKind.night => 'night',
    };
  }

  static List<int> _sortedMonths(Iterable<int> months) {
    return months.toList()..sort();
  }

  static bool _isValidUserId(String value) {
    final normalized = value.trim();

    return normalized.isNotEmpty &&
        normalized == value &&
        !normalized.contains('/');
  }

  static bool _isValidCallId(String value) {
    final revision = int.tryParse(value);

    return revision != null && revision > 0 && revision.toString() == value;
  }

  static bool _sameKeys(Iterable<Object?> first, Iterable<Object?> second) {
    final firstSet = first.toSet();
    final secondSet = second.toSet();

    return firstSet.length == secondSet.length &&
        firstSet.every(secondSet.contains);
  }
}
