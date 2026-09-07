import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_participant.dart';
import 'substitution_participant_mapper.dart';

typedef SubstitutionParticipantDocumentUpdater =
    Future<void> Function({
      required String userId,
      required Map<String, dynamic> data,
    });

final class SubstitutionParticipantStateFirestoreGateway {
  SubstitutionParticipantStateFirestoreGateway({
    required SubstitutionParticipantDocumentUpdater documentUpdater,
  }) : _updateDocument = documentUpdater;

  factory SubstitutionParticipantStateFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final participantsReference = resolvedFirestore
        .collection('spaces')
        .doc('substitution')
        .collection('participants');

    return SubstitutionParticipantStateFirestoreGateway(
      documentUpdater:
          ({required String userId, required Map<String, dynamic> data}) {
            return participantsReference.doc(userId).update(data);
          },
    );
  }

  final SubstitutionParticipantDocumentUpdater _updateDocument;

  Future<void> updateAvailability({
    required String userId,
    required SubstitutionAvailability availability,
  }) {
    return _updateDocument(
      userId: userId,
      data: <String, dynamic>{
        SubstitutionParticipantMapper.availabilityField:
            availability.storageValue,
      },
    );
  }

  Future<void> updateStatus({
    required String userId,
    required SubstitutionParticipantStatus status,
  }) {
    return _updateDocument(
      userId: userId,
      data: <String, dynamic>{
        SubstitutionParticipantMapper.statusField: status.storageValue,
      },
    );
  }
}
