import 'package:epistola/domain/models/substitution_pending_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubstitutionPendingCall', () {
    final calledAt = DateTime.utc(2026, 8, 31, 10);

    SubstitutionPendingCall pendingCall() {
      return SubstitutionPendingCall(
        callId: '7',
        userId: 'user-1',
        revision: 7,
        calledByUserId: 'brigadier-1',
        calledAt: calledAt,
        shift: SubstitutionShift(
          year: 2026,
          month: 8,
          day: 31,
          kind: SubstitutionShiftKind.night,
        ),
      );
    }

    test('undo deadline is six seconds after call', () {
      expect(
        pendingCall().undoDeadline,
        calledAt.add(const Duration(seconds: 6)),
      );
    });

    test('undo window is open before six seconds', () {
      expect(
        pendingCall().isUndoWindowOpenAt(
          calledAt.add(const Duration(seconds: 5, milliseconds: 999)),
        ),
        isTrue,
      );
    });

    test('undo window is closed exactly at six seconds', () {
      expect(
        pendingCall().isUndoWindowOpenAt(
          calledAt.add(const Duration(seconds: 6)),
        ),
        isFalse,
      );

      expect(
        pendingCall().canFinalizeAt(calledAt.add(const Duration(seconds: 6))),
        isTrue,
      );
    });

    test('preserves selected night shift', () {
      final call = pendingCall();

      expect(call.shift.year, 2026);
      expect(call.shift.month, 8);
      expect(call.shift.day, 31);
      expect(call.shift.kind, SubstitutionShiftKind.night);

      expect(call.shift.statisticsYear, 2026);
      expect(call.shift.statisticsMonth, 8);
    });

    test('may preserve next day shift instead', () {
      final call = SubstitutionPendingCall(
        callId: '8',
        userId: 'user-1',
        revision: 8,
        calledByUserId: 'brigadier-1',
        calledAt: calledAt,
        shift: SubstitutionShift(
          year: 2026,
          month: 9,
          day: 1,
          kind: SubstitutionShiftKind.day,
        ),
      );

      expect(call.shift.statisticsYear, 2026);
      expect(call.shift.statisticsMonth, 9);
    });
  });
}
