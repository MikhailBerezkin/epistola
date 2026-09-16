import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_shift.dart';

final class SubstitutionShiftAlreadyCalledException implements Exception {
  const SubstitutionShiftAlreadyCalledException({
    required this.userId,
    required this.shift,
  });

  final String userId;
  final SubstitutionShift shift;

  @override
  String toString() {
    return 'Participant $userId is already called for '
        '${shift.year}-${shift.month}-${shift.day} ${shift.kind.name}.';
  }
}

final class SubstitutionShiftCallClaim {
  const SubstitutionShiftCallClaim._();

  static const int schemaVersion = 1;

  static const String schemaVersionField = 'schemaVersion';
  static const String userIdField = 'userId';
  static const String callIdField = 'callId';
  static const String calledByUserIdField = 'calledByUserId';
  static const String createdAtField = 'createdAt';

  static const String shiftYearField = 'shiftYear';
  static const String shiftMonthField = 'shiftMonth';
  static const String shiftDayField = 'shiftDay';
  static const String shiftKindField = 'shiftKind';

  static String idFor({
    required String userId,
    required SubstitutionShift shift,
  }) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty ||
        normalizedUserId != userId ||
        normalizedUserId.contains('/')) {
      throw ArgumentError.value(
        userId,
        'userId',
        'userId must be normalized, non-empty and contain no slashes.',
      );
    }

    final shiftKind = switch (shift.kind) {
      SubstitutionShiftKind.day => 'day',
      SubstitutionShiftKind.night => 'night',
    };

    return '${normalizedUserId}__${shift.year}_${shift.month}_${shift.day}__$shiftKind';
  }

  static Map<String, dynamic> toCreateMap({
    required String userId,
    required String callId,
    required String calledByUserId,
    required SubstitutionShift shift,
  }) {
    return <String, dynamic>{
      schemaVersionField: schemaVersion,
      userIdField: userId,
      callIdField: callId,
      calledByUserIdField: calledByUserId,
      createdAtField: FieldValue.serverTimestamp(),
      shiftYearField: shift.year,
      shiftMonthField: shift.month,
      shiftDayField: shift.day,
      shiftKindField: switch (shift.kind) {
        SubstitutionShiftKind.day => 'day',
        SubstitutionShiftKind.night => 'night',
      },
    };
  }
}
