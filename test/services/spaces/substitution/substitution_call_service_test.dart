import 'package:epistola/domain/models/substitution_call_receipt.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/substitution/substitution_call_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calls normalized participant and caller ids', () async {
    String? calledUserId;
    String? callerUserId;
    SubstitutionShift? receivedShift;

    final service = SubstitutionCallService(
      participantCaller:
          ({
            required String userId,
            required String calledByUserId,
            required SubstitutionShift shift,
          }) async {
            calledUserId = userId;
            callerUserId = calledByUserId;
            receivedShift = shift;

            return SubstitutionCallReceipt(userId: userId, revision: 1);
          },
      callUndoer: ({required SubstitutionCallReceipt receipt}) async {
        return false;
      },
    );

    final shift = _testShift();

    final receipt = await service.callParticipant(
      userId: ' user-1 ',
      calledByUserId: ' brigadier-1 ',
      shift: shift,
    );

    expect(calledUserId, 'user-1');
    expect(callerUserId, 'brigadier-1');
    expect(receivedShift, same(shift));
    expect(receipt.userId, 'user-1');
    expect(receipt.revision, 1);
    expect(receipt.callId, '1');
  });

  test('passes last call receipt to undo', () async {
    SubstitutionCallReceipt? receivedReceipt;

    final service = SubstitutionCallService(
      participantCaller:
          ({
            required String userId,
            required String calledByUserId,
            required SubstitutionShift shift,
          }) async {
            return SubstitutionCallReceipt(userId: userId, revision: 1);
          },
      callUndoer: ({required SubstitutionCallReceipt receipt}) async {
        receivedReceipt = receipt;
        return true;
      },
    );

    final undone = await service.undoLastCall(
      receipt: const SubstitutionCallReceipt(userId: ' user-1 ', revision: 7),
    );

    expect(undone, isTrue);
    expect(receivedReceipt, isNotNull);
    expect(receivedReceipt!.userId, 'user-1');
    expect(receivedReceipt!.revision, 7);
    expect(receivedReceipt!.callId, '7');
  });

  test('undo may be rejected when receipt is no longer latest', () async {
    final service = SubstitutionCallService(
      participantCaller:
          ({
            required String userId,
            required String calledByUserId,
            required SubstitutionShift shift,
          }) async {
            return SubstitutionCallReceipt(userId: userId, revision: 1);
          },
      callUndoer: ({required SubstitutionCallReceipt receipt}) async {
        return false;
      },
    );

    final undone = await service.undoLastCall(
      receipt: const SubstitutionCallReceipt(userId: 'user-1', revision: 2),
    );

    expect(undone, isFalse);
  });

  test('rejects invalid participant id on call', () {
    final service = _service();

    expect(
      () => service.callParticipant(
        userId: 'user/1',
        calledByUserId: 'brigadier-1',
        shift: _testShift(),
      ),
      throwsArgumentError,
    );
  });

  test('rejects invalid caller id on call', () {
    final service = _service();

    expect(
      () => service.callParticipant(
        userId: 'user-1',
        calledByUserId: 'brigadier/1',
        shift: _testShift(),
      ),
      throwsArgumentError,
    );
  });

  test('rejects invalid participant id on undo', () {
    final service = _service();

    expect(
      () => service.undoLastCall(
        receipt: const SubstitutionCallReceipt(userId: 'user/1', revision: 1),
      ),
      throwsArgumentError,
    );
  });

  test('rejects non-positive undo revision', () {
    final service = _service();

    expect(
      () => service.undoLastCall(
        receipt: const SubstitutionCallReceipt(userId: 'user-1', revision: 0),
      ),
      throwsArgumentError,
    );
  });
}

SubstitutionCallService _service() {
  return SubstitutionCallService(
    participantCaller:
        ({
          required String userId,
          required String calledByUserId,
          required SubstitutionShift shift,
        }) async {
          return SubstitutionCallReceipt(userId: userId, revision: 1);
        },
    callUndoer: ({required SubstitutionCallReceipt receipt}) async {
      return true;
    },
  );
}

SubstitutionShift _testShift() {
  return SubstitutionShift(
    year: 2026,
    month: 8,
    day: 31,
    kind: SubstitutionShiftKind.night,
  );
}
