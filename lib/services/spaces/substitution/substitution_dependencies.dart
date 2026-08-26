import 'package:cloud_firestore/cloud_firestore.dart';

import 'substitution_participant_actions_service.dart';
import 'substitution_participant_firestore_gateway.dart';

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
