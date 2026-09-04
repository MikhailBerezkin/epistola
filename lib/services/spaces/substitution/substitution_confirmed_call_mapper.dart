import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_confirmed_call.dart';
import '../../../domain/models/substitution_pending_call.dart';
import '../../../domain/models/substitution_shift.dart';

final class SubstitutionConfirmedCallMapper {
  const SubstitutionConfirmedCallMapper._();

  static const int schemaVersion = 1;

  static const String schemaVersionField = 'schemaVersion';
  static const String callIdField = 'callId';
  static const String userIdField = 'userId';
  static const String revisionField = 'revision';
  static const String calledByUserIdField = 'calledByUserId';
  static const String calledAtField = 'calledAt';
  static const String finalizedAtField = 'finalizedAt';

  static const String shiftYearField = 'shiftYear';
  static const String shiftMonthField = 'shiftMonth';
  static const String shiftDayField = 'shiftDay';
  static const String shiftKindField = 'shiftKind';

  static const Set<String> _allowedFields = <String>{
    schemaVersionField,
    callIdField,
    userIdField,
    revisionField,
    calledByUserIdField,
    calledAtField,
    finalizedAtField,
    shiftYearField,
    shiftMonthField,
    shiftDayField,
    shiftKindField,
  };

  static Map<String, dynamic> toCreateMap({
    required SubstitutionPendingCall pendingCall,
    required Timestamp calledAt,
  }) {
    final rawCalledAtUtc = calledAt.toDate().toUtc();

    if (rawCalledAtUtc != pendingCall.calledAt.toUtc()) {
      throw ArgumentError.value(
        calledAt,
        'calledAt',
        'must match pendingCall.calledAt',
      );
    }

    return <String, dynamic>{
      schemaVersionField: schemaVersion,
      callIdField: pendingCall.callId,
      userIdField: pendingCall.userId,
      revisionField: pendingCall.revision,
      calledByUserIdField: pendingCall.calledByUserId,
      calledAtField: calledAt,
      finalizedAtField: FieldValue.serverTimestamp(),
      shiftYearField: pendingCall.shift.year,
      shiftMonthField: pendingCall.shift.month,
      shiftDayField: pendingCall.shift.day,
      shiftKindField: _shiftKindToStorage(pendingCall.shift.kind),
    };
  }

  static SubstitutionConfirmedCall? fromMap(Map<String, dynamic> data) {
    if (data.length != _allowedFields.length ||
        !data.keys.every(_allowedFields.contains)) {
      return null;
    }

    final rawSchemaVersion = data[schemaVersionField];
    final callId = data[callIdField];
    final userId = data[userIdField];
    final revision = data[revisionField];
    final calledByUserId = data[calledByUserIdField];
    final calledAt = data[calledAtField];
    final finalizedAt = data[finalizedAtField];

    final shiftYear = data[shiftYearField];
    final shiftMonth = data[shiftMonthField];
    final shiftDay = data[shiftDayField];
    final rawShiftKind = data[shiftKindField];

    if (rawSchemaVersion != schemaVersion ||
        callId is! String ||
        userId is! String ||
        revision is! int ||
        calledByUserId is! String ||
        calledAt is! Timestamp ||
        finalizedAt is! Timestamp ||
        shiftYear is! int ||
        shiftMonth is! int ||
        shiftDay is! int ||
        rawShiftKind is! String) {
      return null;
    }

    if (!_isValidId(callId) ||
        !_isValidId(userId) ||
        !_isValidId(calledByUserId) ||
        revision < 1 ||
        callId != revision.toString()) {
      return null;
    }

    final calledAtUtc = calledAt.toDate().toUtc();
    final finalizedAtUtc = finalizedAt.toDate().toUtc();

    if (finalizedAtUtc.isBefore(
      calledAtUtc.add(SubstitutionPendingCall.undoWindow),
    )) {
      return null;
    }

    final shiftKind = _shiftKindFromStorage(rawShiftKind);

    if (shiftKind == null) {
      return null;
    }

    try {
      final shift = SubstitutionShift(
        year: shiftYear,
        month: shiftMonth,
        day: shiftDay,
        kind: shiftKind,
      );

      return SubstitutionConfirmedCall(
        callId: callId,
        userId: userId,
        revision: revision,
        calledByUserId: calledByUserId,
        calledAt: calledAtUtc,
        finalizedAt: finalizedAtUtc,
        shift: shift,
      );
    } on ArgumentError {
      return null;
    }
  }

  static String _shiftKindToStorage(SubstitutionShiftKind kind) {
    return switch (kind) {
      SubstitutionShiftKind.day => 'day',
      SubstitutionShiftKind.night => 'night',
    };
  }

  static SubstitutionShiftKind? _shiftKindFromStorage(String value) {
    return switch (value) {
      'day' => SubstitutionShiftKind.day,
      'night' => SubstitutionShiftKind.night,
      _ => null,
    };
  }

  static bool _isValidId(String value) {
    final normalized = value.trim();

    return normalized.isNotEmpty &&
        normalized == value &&
        !normalized.contains('/');
  }
}
