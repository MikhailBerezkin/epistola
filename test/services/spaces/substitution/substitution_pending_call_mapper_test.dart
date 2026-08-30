import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/substitution/substitution_pending_call_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubstitutionPendingCallMapper', () {
    test('creates pending call map with selected night shift', () {
      final data = SubstitutionPendingCallMapper.toCreateMap(
        callId: '7',
        userId: 'user-1',
        revision: 7,
        calledByUserId: 'brigadier-1',
        shift: SubstitutionShift(
          year: 2026,
          month: 8,
          day: 31,
          kind: SubstitutionShiftKind.night,
        ),
      );

      expect(data['callId'], '7');
      expect(data['userId'], 'user-1');
      expect(data['revision'], 7);
      expect(data['calledByUserId'], 'brigadier-1');

      expect(data['shiftYear'], 2026);
      expect(data['shiftMonth'], 8);
      expect(data['shiftDay'], 31);
      expect(data['shiftKind'], 'night');

      expect(data['calledAt'], isA<FieldValue>());
      expect(data.length, 9);
    });

    test('reads valid night shift pending call', () {
      final calledAt = DateTime.utc(2026, 8, 31, 10);

      final pending = SubstitutionPendingCallMapper.fromMap(<String, dynamic>{
        'callId': '7',
        'userId': 'user-1',
        'revision': 7,
        'calledByUserId': 'brigadier-1',
        'calledAt': Timestamp.fromDate(calledAt),
        'shiftYear': 2026,
        'shiftMonth': 8,
        'shiftDay': 31,
        'shiftKind': 'night',
      });

      expect(pending, isNotNull);
      expect(pending!.callId, '7');
      expect(pending.userId, 'user-1');
      expect(pending.revision, 7);
      expect(pending.calledByUserId, 'brigadier-1');
      expect(pending.calledAt, calledAt);

      expect(pending.shift.year, 2026);
      expect(pending.shift.month, 8);
      expect(pending.shift.day, 31);
      expect(pending.shift.kind, SubstitutionShiftKind.night);
    });

    test('reads valid day shift pending call', () {
      final pending = SubstitutionPendingCallMapper.fromMap(<String, dynamic>{
        'callId': '8',
        'userId': 'user-1',
        'revision': 8,
        'calledByUserId': 'brigadier-1',
        'calledAt': Timestamp.fromDate(DateTime.utc(2026, 8, 31, 13)),
        'shiftYear': 2026,
        'shiftMonth': 9,
        'shiftDay': 1,
        'shiftKind': 'day',
      });

      expect(pending, isNotNull);
      expect(pending!.shift.month, 9);
      expect(pending.shift.day, 1);
      expect(pending.shift.kind, SubstitutionShiftKind.day);
    });

    test('rejects pending call with wrong call id', () {
      final pending = SubstitutionPendingCallMapper.fromMap(<String, dynamic>{
        'callId': '6',
        'userId': 'user-1',
        'revision': 7,
        'calledByUserId': 'brigadier-1',
        'calledAt': Timestamp.now(),
        'shiftYear': 2026,
        'shiftMonth': 8,
        'shiftDay': 31,
        'shiftKind': 'night',
      });

      expect(pending, isNull);
    });

    test('rejects unknown shift kind', () {
      final pending = SubstitutionPendingCallMapper.fromMap(<String, dynamic>{
        'callId': '7',
        'userId': 'user-1',
        'revision': 7,
        'calledByUserId': 'brigadier-1',
        'calledAt': Timestamp.now(),
        'shiftYear': 2026,
        'shiftMonth': 8,
        'shiftDay': 31,
        'shiftKind': 'evening',
      });

      expect(pending, isNull);
    });

    test('rejects impossible shift date', () {
      final pending = SubstitutionPendingCallMapper.fromMap(<String, dynamic>{
        'callId': '7',
        'userId': 'user-1',
        'revision': 7,
        'calledByUserId': 'brigadier-1',
        'calledAt': Timestamp.now(),
        'shiftYear': 2026,
        'shiftMonth': 2,
        'shiftDay': 31,
        'shiftKind': 'night',
      });

      expect(pending, isNull);
    });

    test('rejects missing shift field', () {
      final pending = SubstitutionPendingCallMapper.fromMap(<String, dynamic>{
        'callId': '7',
        'userId': 'user-1',
        'revision': 7,
        'calledByUserId': 'brigadier-1',
        'calledAt': Timestamp.now(),
        'shiftYear': 2026,
        'shiftMonth': 8,
        'shiftDay': 31,
      });

      expect(pending, isNull);
    });

    test('rejects extra field', () {
      final pending = SubstitutionPendingCallMapper.fromMap(<String, dynamic>{
        'callId': '7',
        'userId': 'user-1',
        'revision': 7,
        'calledByUserId': 'brigadier-1',
        'calledAt': Timestamp.now(),
        'shiftYear': 2026,
        'shiftMonth': 8,
        'shiftDay': 31,
        'shiftKind': 'night',
        'extra': true,
      });

      expect(pending, isNull);
    });
  });
}
