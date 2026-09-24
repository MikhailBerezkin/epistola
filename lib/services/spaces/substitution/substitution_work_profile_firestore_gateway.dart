import 'package:cloud_firestore/cloud_firestore.dart';

typedef SubstitutionWorkProfileDocumentUpdater =
    Future<void> Function({
      required String userId,
      required Map<String, dynamic> data,
    });

final class SubstitutionWorkProfileFirestoreGateway {
  SubstitutionWorkProfileFirestoreGateway({
    required SubstitutionWorkProfileDocumentUpdater documentUpdater,
  }) : _updateDocument = documentUpdater;

  factory SubstitutionWorkProfileFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;
    final usersReference = resolvedFirestore.collection('users');

    return SubstitutionWorkProfileFirestoreGateway(
      documentUpdater:
          ({required String userId, required Map<String, dynamic> data}) {
            return usersReference.doc(userId).update(data);
          },
    );
  }

  static const String workDisplayNameField = 'workDisplayName';
  static const String assignedCrewField = 'assignedCrew';

  final SubstitutionWorkProfileDocumentUpdater _updateDocument;

  Future<void> updateWorkProfile({
    required String userId,
    required String workDisplayName,
    required int crewNumber,
  }) {
    return _updateDocument(
      userId: userId,
      data: <String, dynamic>{
        workDisplayNameField: workDisplayName,
        assignedCrewField: crewNumber,
      },
    );
  }
}
