import 'package:epistola/domain/models/substitution_pending_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/substitution/substitution_call_reconciliation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseTime = DateTime.utc(2026, 8, 31, 10);

  SubstitutionPendingCall pendingCall({
    required int revision,
    required DateTime calledAt,
  }) {
    return SubstitutionPendingCall(
      callId: revision.toString(),
      userId: 'user-1',
      revision: revision,
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

  test('does nothing when there are no pending calls', () async {
    var finalizeCount = 0;

    final service = SubstitutionCallReconciliationService(
      pendingCallsLoader: () async {
        return <SubstitutionPendingCall>[];
      },
      pendingCallFinalizer: ({required String callId}) async {
        finalizeCount += 1;
        return true;
      },
    );

    final result = await service.reconcileExpiredPendingCalls(now: baseTime);

    expect(result, 0);
    expect(finalizeCount, 0);
  });

  test('does not finalize call while undo window is open', () async {
    final finalizedCallIds = <String>[];

    final service = SubstitutionCallReconciliationService(
      pendingCallsLoader: () async {
        return <SubstitutionPendingCall>[
          pendingCall(revision: 1, calledAt: baseTime),
        ];
      },
      pendingCallFinalizer: ({required String callId}) async {
        finalizedCallIds.add(callId);
        return true;
      },
    );

    final result = await service.reconcileExpiredPendingCalls(
      now: baseTime.add(const Duration(seconds: 5, milliseconds: 999)),
    );

    expect(result, 0);
    expect(finalizedCallIds, isEmpty);
  });

  test('finalizes call exactly at six second boundary', () async {
    final finalizedCallIds = <String>[];

    final service = SubstitutionCallReconciliationService(
      pendingCallsLoader: () async {
        return <SubstitutionPendingCall>[
          pendingCall(revision: 1, calledAt: baseTime),
        ];
      },
      pendingCallFinalizer: ({required String callId}) async {
        finalizedCallIds.add(callId);
        return true;
      },
    );

    final result = await service.reconcileExpiredPendingCalls(
      now: baseTime.add(const Duration(seconds: 6)),
    );

    expect(result, 1);
    expect(finalizedCallIds, <String>['1']);
  });

  test('finalizes expired calls in revision order', () async {
    final finalizedCallIds = <String>[];

    final service = SubstitutionCallReconciliationService(
      pendingCallsLoader: () async {
        return <SubstitutionPendingCall>[
          pendingCall(revision: 3, calledAt: baseTime),
          pendingCall(revision: 1, calledAt: baseTime),
          pendingCall(revision: 2, calledAt: baseTime),
        ];
      },
      pendingCallFinalizer: ({required String callId}) async {
        finalizedCallIds.add(callId);
        return true;
      },
    );

    final result = await service.reconcileExpiredPendingCalls(
      now: baseTime.add(const Duration(seconds: 10)),
    );

    expect(result, 3);
    expect(finalizedCallIds, <String>['1', '2', '3']);
  });

  test('continues when another device already finalized one call', () async {
    final finalizedCallIds = <String>[];

    final service = SubstitutionCallReconciliationService(
      pendingCallsLoader: () async {
        return <SubstitutionPendingCall>[
          pendingCall(revision: 1, calledAt: baseTime),
          pendingCall(revision: 2, calledAt: baseTime),
        ];
      },
      pendingCallFinalizer: ({required String callId}) async {
        finalizedCallIds.add(callId);

        return callId == '2';
      },
    );

    final result = await service.reconcileExpiredPendingCalls(
      now: baseTime.add(const Duration(seconds: 10)),
    );

    expect(result, 1);

    expect(finalizedCallIds, <String>['1', '2']);
  });
  test('finalizePendingCall forwards exact callId', () async {
    String? finalizedCallId;

    final service = SubstitutionCallReconciliationService(
      pendingCallsLoader: () async {
        return <SubstitutionPendingCall>[];
      },
      pendingCallFinalizer: ({required String callId}) async {
        finalizedCallId = callId;
        return true;
      },
    );

    final result = await service.finalizePendingCall(callId: '37');

    expect(result, true);
    expect(finalizedCallId, '37');
  });
}
