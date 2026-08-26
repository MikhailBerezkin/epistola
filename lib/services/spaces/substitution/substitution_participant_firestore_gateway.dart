import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_participant.dart';
import 'substitution_participant_mapper.dart';

typedef SubstitutionParticipantDocumentUpdater =
    Future<void> Function({
      required String userId,
      required Map<String, dynamic> data,
    });

typedef SubstitutionParticipantDocumentDeleter =
    Future<void> Function({required String userId});

final class SubstitutionParticipantFirestoreGateway {
  SubstitutionParticipantFirestoreGateway({
    required SubstitutionParticipantDocumentUpdater documentUpdater,
    required SubstitutionParticipantDocumentDeleter documentDeleter,
  }) : _updateDocument = documentUpdater,
       _deleteDocument = documentDeleter;

  factory SubstitutionParticipantFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final participantsReference = resolvedFirestore
        .collection('spaces')
        .doc('substitution')
        .collection('participants');

    return SubstitutionParticipantFirestoreGateway(
      documentUpdater:
          ({required String userId, required Map<String, dynamic> data}) {
            return participantsReference.doc(userId).update(data);
          },
      documentDeleter: ({required String userId}) {
        return participantsReference.doc(userId).delete();
      },
    );
  }

  final SubstitutionParticipantDocumentUpdater _updateDocument;
  final SubstitutionParticipantDocumentDeleter _deleteDocument;

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

  Future<void> removeParticipant({required String userId}) {
    return _deleteDocument(userId: userId);
  }
}
