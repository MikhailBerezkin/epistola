import 'package:cloud_firestore/cloud_firestore.dart';

typedef SubstitutionWorkDisplayNameDocumentUpdater =
    Future<void> Function({
      required String userId,
      required Map<String, dynamic> data,
    });

final class SubstitutionWorkDisplayNameFirestoreGateway {
  SubstitutionWorkDisplayNameFirestoreGateway({
    required SubstitutionWorkDisplayNameDocumentUpdater documentUpdater,
  }) : _updateDocument = documentUpdater;

  factory SubstitutionWorkDisplayNameFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;
    final usersReference = resolvedFirestore.collection('users');

    return SubstitutionWorkDisplayNameFirestoreGateway(
      documentUpdater:
          ({required String userId, required Map<String, dynamic> data}) {
            return usersReference.doc(userId).update(data);
          },
    );
  }

  static const String workDisplayNameField = 'workDisplayName';

  final SubstitutionWorkDisplayNameDocumentUpdater _updateDocument;

  Future<void> updateWorkDisplayName({
    required String userId,
    required String workDisplayName,
  }) {
    return _updateDocument(
      userId: userId,
      data: <String, dynamic>{workDisplayNameField: workDisplayName},
    );
  }
}
