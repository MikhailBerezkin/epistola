import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_pending_call.dart';
import '../../../domain/models/substitution_shift.dart';

final class SubstitutionPendingCallMapper {
  const SubstitutionPendingCallMapper._();

  static const String callIdField = 'callId';
  static const String userIdField = 'userId';
  static const String revisionField = 'revision';
  static const String calledByUserIdField = 'calledByUserId';
  static const String calledAtField = 'calledAt';

  static const String shiftYearField = 'shiftYear';
  static const String shiftMonthField = 'shiftMonth';
  static const String shiftDayField = 'shiftDay';
  static const String shiftKindField = 'shiftKind';

  static const Set<String> _allowedFields = <String>{
    callIdField,
    userIdField,
    revisionField,
    calledByUserIdField,
    calledAtField,
    shiftYearField,
    shiftMonthField,
    shiftDayField,
    shiftKindField,
  };

  static Map<String, dynamic> toCreateMap({
    required String callId,
    required String userId,
    required int revision,
    required String calledByUserId,
    required SubstitutionShift shift,
  }) {
    return <String, dynamic>{
      callIdField: callId,
      userIdField: userId,
      revisionField: revision,
      calledByUserIdField: calledByUserId,
      calledAtField: FieldValue.serverTimestamp(),
      shiftYearField: shift.year,
      shiftMonthField: shift.month,
      shiftDayField: shift.day,
      shiftKindField: _shiftKindToStorage(shift.kind),
    };
  }

  static SubstitutionPendingCall? fromMap(Map<String, dynamic> data) {
    if (data.length != _allowedFields.length ||
        !data.keys.every(_allowedFields.contains)) {
      return null;
    }

    final callId = data[callIdField];
    final userId = data[userIdField];
    final revision = data[revisionField];
    final calledByUserId = data[calledByUserIdField];
    final calledAt = data[calledAtField];

    final shiftYear = data[shiftYearField];
    final shiftMonth = data[shiftMonthField];
    final shiftDay = data[shiftDayField];
    final rawShiftKind = data[shiftKindField];

    if (callId is! String ||
        userId is! String ||
        revision is! int ||
        calledByUserId is! String ||
        calledAt is! Timestamp ||
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

      return SubstitutionPendingCall(
        callId: callId,
        userId: userId,
        revision: revision,
        calledByUserId: calledByUserId,
        calledAt: calledAt.toDate().toUtc(),
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
