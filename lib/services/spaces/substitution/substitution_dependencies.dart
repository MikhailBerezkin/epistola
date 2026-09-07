import 'package:cloud_firestore/cloud_firestore.dart';

import 'substitution_call_finalization_firestore_gateway.dart';
import 'substitution_call_firestore_gateway.dart';
import 'substitution_call_reconciliation_service.dart';
import 'substitution_call_service.dart';
import 'substitution_participant_actions_service.dart';
import 'substitution_participant_state_firestore_gateway.dart';
import 'substitution_pending_call_firestore_gateway.dart';
import 'substitution_rotation_edit_firestore_gateway.dart';
import 'substitution_rotation_edit_service.dart';
import 'substitution_statistics_firestore_gateway.dart';
import 'substitution_statistics_service.dart';
import 'substitution_work_display_name_firestore_gateway.dart';
import 'substitution_work_display_name_service.dart';
import 'substitution_rotation_membership_firestore_gateway.dart';

SubstitutionParticipantActionsService
createSubstitutionParticipantActionsService({
  FirebaseFirestore? firestore,
  SubstitutionParticipantStateFirestoreGateway? gateway,
  SubstitutionParticipantRemover? membershipRemover,
}) {
  final resolvedGateway =
      gateway ??
      SubstitutionParticipantStateFirestoreGateway.firebase(
        firestore: firestore,
      );

  final resolvedMembershipRemover =
      membershipRemover ??
      ({required String userId}) {
        final membershipGateway =
            SubstitutionRotationMembershipFirestoreGateway.firebase(
              firestore: firestore,
            );

        return membershipGateway.removeParticipant(userId: userId);
      };

  return SubstitutionParticipantActionsService(
    availabilityWriter: resolvedGateway.updateAvailability,
    statusWriter: resolvedGateway.updateStatus,
    participantRemover: resolvedMembershipRemover,
  );
}

SubstitutionCallService createSubstitutionCallService({
  FirebaseFirestore? firestore,
  SubstitutionCallFirestoreGateway? gateway,
}) {
  final resolvedGateway =
      gateway ??
      SubstitutionCallFirestoreGateway.firebase(firestore: firestore);

  return SubstitutionCallService(
    participantCaller: resolvedGateway.callParticipant,
    callUndoer: resolvedGateway.undoLastCall,
  );
}

SubstitutionRotationEditService createSubstitutionRotationEditService({
  FirebaseFirestore? firestore,
  SubstitutionRotationEditFirestoreGateway? gateway,
}) {
  final resolvedGateway =
      gateway ??
      SubstitutionRotationEditFirestoreGateway.firebase(firestore: firestore);

  return SubstitutionRotationEditService(
    baselineLoader: () async {
      final baseline = await resolvedGateway.loadBaseline();

      return SubstitutionRotationEditBaseline(
        nextRotationOrder: baseline.nextRotationOrder,
        revision: baseline.revision,
      );
    },
    rotationWriter: resolvedGateway.applyOrder,
  );
}

SubstitutionCallReconciliationService
createSubstitutionCallReconciliationService({
  FirebaseFirestore? firestore,
  SubstitutionPendingCallFirestoreGateway? pendingCallGateway,
  SubstitutionCallFinalizationFirestoreGateway? finalizationGateway,
}) {
  final resolvedPendingCallGateway =
      pendingCallGateway ??
      SubstitutionPendingCallFirestoreGateway.firebase(firestore: firestore);

  final resolvedFinalizationGateway =
      finalizationGateway ??
      SubstitutionCallFinalizationFirestoreGateway.firebase(
        firestore: firestore,
      );

  return SubstitutionCallReconciliationService(
    pendingCallsLoader: resolvedPendingCallGateway.loadPendingCalls,
    pendingCallFinalizer: resolvedFinalizationGateway.finalizePendingCall,
  );
}

SubstitutionStatisticsService createSubstitutionStatisticsService({
  FirebaseFirestore? firestore,
  SubstitutionStatisticsFirestoreGateway? gateway,
}) {
  final resolvedGateway =
      gateway ??
      SubstitutionStatisticsFirestoreGateway.firebase(firestore: firestore);

  return SubstitutionStatisticsService(statisticsLoader: resolvedGateway.load);
}

SubstitutionWorkDisplayNameService createSubstitutionWorkDisplayNameService({
  FirebaseFirestore? firestore,
  SubstitutionWorkDisplayNameFirestoreGateway? gateway,
}) {
  final resolvedGateway =
      gateway ??
      SubstitutionWorkDisplayNameFirestoreGateway.firebase(
        firestore: firestore,
      );

  return SubstitutionWorkDisplayNameService(
    workDisplayNameWriter: resolvedGateway.updateWorkDisplayName,
  );
}
