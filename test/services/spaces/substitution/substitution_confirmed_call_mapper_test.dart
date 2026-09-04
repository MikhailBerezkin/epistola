import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/substitution_pending_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/substitution/substitution_confirmed_call_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubstitutionConfirmedCallMapper', () {
    test('creates confirmed call map from pending night call', () {
      final calledAt = Timestamp.fromDate(DateTime.utc(2026, 9, 4, 16));

      final pendingCall = SubstitutionPendingCall(
        callId: '7',
        userId: 'user-1',
        revision: 7,
        calledByUserId: 'brigadier-1',
        calledAt: calledAt.toDate().toUtc(),
        shift: SubstitutionShift(
          year: 2026,
          month: 9,
          day: 4,
          kind: SubstitutionShiftKind.night,
        ),
      );

      final data = SubstitutionConfirmedCallMapper.toCreateMap(
        pendingCall: pendingCall,
        calledAt: calledAt,
      );

      expect(data['schemaVersion'], 1);
      expect(data['callId'], '7');
      expect(data['userId'], 'user-1');
      expect(data['revision'], 7);
      expect(data['calledByUserId'], 'brigadier-1');
      expect(data['calledAt'], calledAt);
      expect(data['finalizedAt'], isA<FieldValue>());

      expect(data['shiftYear'], 2026);
      expect(data['shiftMonth'], 9);
      expect(data['shiftDay'], 4);
      expect(data['shiftKind'], 'night');

      expect(data.length, 11);
    });

    test('rejects mismatched calledAt when creating map', () {
      final pendingCall = SubstitutionPendingCall(
        callId: '7',
        userId: 'user-1',
        revision: 7,
        calledByUserId: 'brigadier-1',
        calledAt: DateTime.utc(2026, 9, 4, 16),
        shift: SubstitutionShift(
          year: 2026,
          month: 9,
          day: 4,
          kind: SubstitutionShiftKind.night,
        ),
      );

      expect(
        () => SubstitutionConfirmedCallMapper.toCreateMap(
          pendingCall: pendingCall,
          calledAt: Timestamp.fromDate(DateTime.utc(2026, 9, 4, 16, 0, 1)),
        ),
        throwsArgumentError,
      );
    });

    test('reads valid confirmed night call', () {
      final calledAt = DateTime.utc(2026, 9, 4, 16);
      final finalizedAt = calledAt.add(const Duration(seconds: 6));

      final confirmedCall =
          SubstitutionConfirmedCallMapper.fromMap(<String, dynamic>{
            'schemaVersion': 1,
            'callId': '7',
            'userId': 'user-1',
            'revision': 7,
            'calledByUserId': 'brigadier-1',
            'calledAt': Timestamp.fromDate(calledAt),
            'finalizedAt': Timestamp.fromDate(finalizedAt),
            'shiftYear': 2026,
            'shiftMonth': 9,
            'shiftDay': 4,
            'shiftKind': 'night',
          });

      expect(confirmedCall, isNotNull);

      expect(confirmedCall!.callId, '7');
      expect(confirmedCall.userId, 'user-1');
      expect(confirmedCall.revision, 7);
      expect(confirmedCall.calledByUserId, 'brigadier-1');
      expect(confirmedCall.calledAt, calledAt);
      expect(confirmedCall.finalizedAt, finalizedAt);

      expect(confirmedCall.shift.year, 2026);
      expect(confirmedCall.shift.month, 9);
      expect(confirmedCall.shift.day, 4);
      expect(confirmedCall.shift.kind, SubstitutionShiftKind.night);
    });

    test('reads valid confirmed day call', () {
      final calledAt = DateTime.utc(2026, 9, 4, 16);

      final confirmedCall =
          SubstitutionConfirmedCallMapper.fromMap(<String, dynamic>{
            'schemaVersion': 1,
            'callId': '8',
            'userId': 'user-2',
            'revision': 8,
            'calledByUserId': 'owner-1',
            'calledAt': Timestamp.fromDate(calledAt),
            'finalizedAt': Timestamp.fromDate(
              calledAt.add(const Duration(seconds: 10)),
            ),
            'shiftYear': 2026,
            'shiftMonth': 9,
            'shiftDay': 5,
            'shiftKind': 'day',
          });

      expect(confirmedCall, isNotNull);
      expect(confirmedCall!.userId, 'user-2');
      expect(confirmedCall.shift.day, 5);
      expect(confirmedCall.shift.kind, SubstitutionShiftKind.day);
    });

    test('rejects finalized call before undo window expires', () {
      final calledAt = DateTime.utc(2026, 9, 4, 16);

      final confirmedCall =
          SubstitutionConfirmedCallMapper.fromMap(<String, dynamic>{
            'schemaVersion': 1,
            'callId': '7',
            'userId': 'user-1',
            'revision': 7,
            'calledByUserId': 'brigadier-1',
            'calledAt': Timestamp.fromDate(calledAt),
            'finalizedAt': Timestamp.fromDate(
              calledAt.add(const Duration(seconds: 5)),
            ),
            'shiftYear': 2026,
            'shiftMonth': 9,
            'shiftDay': 4,
            'shiftKind': 'night',
          });

      expect(confirmedCall, isNull);
    });

    test('accepts exact undo window boundary', () {
      final calledAt = DateTime.utc(2026, 9, 4, 16);

      final confirmedCall =
          SubstitutionConfirmedCallMapper.fromMap(<String, dynamic>{
            'schemaVersion': 1,
            'callId': '7',
            'userId': 'user-1',
            'revision': 7,
            'calledByUserId': 'brigadier-1',
            'calledAt': Timestamp.fromDate(calledAt),
            'finalizedAt': Timestamp.fromDate(
              calledAt.add(const Duration(seconds: 6)),
            ),
            'shiftYear': 2026,
            'shiftMonth': 9,
            'shiftDay': 4,
            'shiftKind': 'night',
          });

      expect(confirmedCall, isNotNull);
    });

    test('rejects unsupported schema version', () {
      final calledAt = DateTime.utc(2026, 9, 4, 16);

      final confirmedCall =
          SubstitutionConfirmedCallMapper.fromMap(<String, dynamic>{
            'schemaVersion': 2,
            'callId': '7',
            'userId': 'user-1',
            'revision': 7,
            'calledByUserId': 'brigadier-1',
            'calledAt': Timestamp.fromDate(calledAt),
            'finalizedAt': Timestamp.fromDate(
              calledAt.add(const Duration(seconds: 6)),
            ),
            'shiftYear': 2026,
            'shiftMonth': 9,
            'shiftDay': 4,
            'shiftKind': 'night',
          });

      expect(confirmedCall, isNull);
    });

    test('rejects call id that does not match revision', () {
      final calledAt = DateTime.utc(2026, 9, 4, 16);

      final confirmedCall =
          SubstitutionConfirmedCallMapper.fromMap(<String, dynamic>{
            'schemaVersion': 1,
            'callId': '6',
            'userId': 'user-1',
            'revision': 7,
            'calledByUserId': 'brigadier-1',
            'calledAt': Timestamp.fromDate(calledAt),
            'finalizedAt': Timestamp.fromDate(
              calledAt.add(const Duration(seconds: 6)),
            ),
            'shiftYear': 2026,
            'shiftMonth': 9,
            'shiftDay': 4,
            'shiftKind': 'night',
          });

      expect(confirmedCall, isNull);
    });

    test('rejects unknown shift kind', () {
      final calledAt = DateTime.utc(2026, 9, 4, 16);

      final confirmedCall =
          SubstitutionConfirmedCallMapper.fromMap(<String, dynamic>{
            'schemaVersion': 1,
            'callId': '7',
            'userId': 'user-1',
            'revision': 7,
            'calledByUserId': 'brigadier-1',
            'calledAt': Timestamp.fromDate(calledAt),
            'finalizedAt': Timestamp.fromDate(
              calledAt.add(const Duration(seconds: 6)),
            ),
            'shiftYear': 2026,
            'shiftMonth': 9,
            'shiftDay': 4,
            'shiftKind': 'evening',
          });

      expect(confirmedCall, isNull);
    });

    test('rejects impossible shift date', () {
      final calledAt = DateTime.utc(2026, 9, 4, 16);

      final confirmedCall =
          SubstitutionConfirmedCallMapper.fromMap(<String, dynamic>{
            'schemaVersion': 1,
            'callId': '7',
            'userId': 'user-1',
            'revision': 7,
            'calledByUserId': 'brigadier-1',
            'calledAt': Timestamp.fromDate(calledAt),
            'finalizedAt': Timestamp.fromDate(
              calledAt.add(const Duration(seconds: 6)),
            ),
            'shiftYear': 2026,
            'shiftMonth': 2,
            'shiftDay': 31,
            'shiftKind': 'night',
          });

      expect(confirmedCall, isNull);
    });

    test('rejects invalid user id', () {
      final calledAt = DateTime.utc(2026, 9, 4, 16);

      final confirmedCall =
          SubstitutionConfirmedCallMapper.fromMap(<String, dynamic>{
            'schemaVersion': 1,
            'callId': '7',
            'userId': ' user-1 ',
            'revision': 7,
            'calledByUserId': 'brigadier-1',
            'calledAt': Timestamp.fromDate(calledAt),
            'finalizedAt': Timestamp.fromDate(
              calledAt.add(const Duration(seconds: 6)),
            ),
            'shiftYear': 2026,
            'shiftMonth': 9,
            'shiftDay': 4,
            'shiftKind': 'night',
          });

      expect(confirmedCall, isNull);
    });

    test('rejects extra field', () {
      final calledAt = DateTime.utc(2026, 9, 4, 16);

      final confirmedCall =
          SubstitutionConfirmedCallMapper.fromMap(<String, dynamic>{
            'schemaVersion': 1,
            'callId': '7',
            'userId': 'user-1',
            'revision': 7,
            'calledByUserId': 'brigadier-1',
            'calledAt': Timestamp.fromDate(calledAt),
            'finalizedAt': Timestamp.fromDate(
              calledAt.add(const Duration(seconds: 6)),
            ),
            'shiftYear': 2026,
            'shiftMonth': 9,
            'shiftDay': 4,
            'shiftKind': 'night',
            'extra': true,
          });

      expect(confirmedCall, isNull);
    });
  });
}
