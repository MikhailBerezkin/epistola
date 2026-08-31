import '../../../domain/models/substitution_pending_call.dart';

typedef SubstitutionPendingCallsLoader =
    Future<List<SubstitutionPendingCall>> Function();

typedef SubstitutionPendingCallFinalizer =
    Future<bool> Function({required String callId});

final class SubstitutionCallReconciliationService {
  SubstitutionCallReconciliationService({
    required SubstitutionPendingCallsLoader pendingCallsLoader,
    required SubstitutionPendingCallFinalizer pendingCallFinalizer,
  }) : _loadPendingCalls = pendingCallsLoader,
       _finalizePendingCall = pendingCallFinalizer;

  final SubstitutionPendingCallsLoader _loadPendingCalls;
  final SubstitutionPendingCallFinalizer _finalizePendingCall;

  Future<bool> finalizePendingCall({required String callId}) {
    return _finalizePendingCall(callId: callId);
  }

  Future<int> reconcileExpiredPendingCalls({required DateTime now}) async {
    final pendingCalls = <SubstitutionPendingCall>[...await _loadPendingCalls()]
      ..sort((first, second) => first.revision.compareTo(second.revision));

    final normalizedNow = now.toUtc();

    var finalizedCount = 0;

    for (final pendingCall in pendingCalls) {
      if (!pendingCall.canFinalizeAt(normalizedNow)) {
        continue;
      }

      final finalized = await _finalizePendingCall(callId: pendingCall.callId);

      if (finalized) {
        finalizedCount += 1;
      }
    }

    return finalizedCount;
  }
}
