import 'package:cloud_firestore/cloud_firestore.dart';

import 'substitution_call_firestore_gateway.dart';
import 'substitution_call_service.dart';
import 'substitution_participant_actions_service.dart';
import 'substitution_participant_firestore_gateway.dart';
import 'substitution_work_display_name_firestore_gateway.dart';
import 'substitution_work_display_name_service.dart';

SubstitutionParticipantActionsService
createSubstitutionParticipantActionsService({
  FirebaseFirestore? firestore,
  SubstitutionParticipantFirestoreGateway? gateway,
}) {
  final resolvedGateway =
      gateway ??
      SubstitutionParticipantFirestoreGateway.firebase(firestore: firestore);

  return SubstitutionParticipantActionsService(
    availabilityWriter: resolvedGateway.updateAvailability,
    statusWriter: resolvedGateway.updateStatus,
    participantRemover: resolvedGateway.removeParticipant,
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
