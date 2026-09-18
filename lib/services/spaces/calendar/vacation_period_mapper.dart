import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/vacation_period.dart';

final class VacationPeriodMapper {
  const VacationPeriodMapper._();

  static const int schemaVersion = 1;

  static const String schemaVersionField = 'schemaVersion';
  static const String userIdField = 'userId';
  static const String slotField = 'slot';
  static const String startDayField = 'startDay';
  static const String endDayField = 'endDay';
  static const String updatedAtField = 'updatedAt';

  static const Set<String> _allowedFields = <String>{
    schemaVersionField,
    userIdField,
    slotField,
    startDayField,
    endDayField,
    updatedAtField,
  };

  static Map<String, dynamic> toMap(VacationPeriod period) {
    if (!period.isValid) {
      throw ArgumentError.value(
        period,
        'period',
        'must be a valid vacation period',
      );
    }

    return <String, dynamic>{
      schemaVersionField: schemaVersion,
      userIdField: period.userId.trim(),
      slotField: period.slot,
      startDayField: _toDayKey(period.startDateOnly),
      endDayField: _toDayKey(period.endDateOnly),
      updatedAtField: FieldValue.serverTimestamp(),
    };
  }

  static VacationPeriod? fromMap(Map<String, dynamic> data) {
    if (data.length != _allowedFields.length ||
        !data.keys.every(_allowedFields.contains)) {
      return null;
    }

    final rawSchemaVersion = data[schemaVersionField];
    final userId = data[userIdField];
    final slot = data[slotField];
    final startDay = data[startDayField];
    final endDay = data[endDayField];
    final updatedAt = data[updatedAtField];

    if (rawSchemaVersion != schemaVersion ||
        userId is! String ||
        slot is! int ||
        startDay is! int ||
        endDay is! int ||
        updatedAt is! Timestamp) {
      return null;
    }

    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty ||
        normalizedUserId != userId ||
        normalizedUserId.contains('/') ||
        slot < 1 ||
        slot > 6) {
      return null;
    }

    final startDate = _fromDayKey(startDay);
    final endDate = _fromDayKey(endDay);

    if (startDate == null || endDate == null) {
      return null;
    }

    final period = VacationPeriod(
      userId: userId,
      slot: slot,
      startDate: startDate,
      endDate: endDate,
    );

    return period.isValid ? period : null;
  }

  static int _toDayKey(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  static DateTime? _fromDayKey(int value) {
    final year = value ~/ 10000;
    final month = (value ~/ 100) % 100;
    final day = value % 100;

    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime.utc(year, month, day);

    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }
}
