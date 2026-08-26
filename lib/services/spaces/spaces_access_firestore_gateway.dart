import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/spaces_access_role.dart';

typedef SpacesAccessDocumentReader =
    Future<Map<String, dynamic>?> Function({required String userId});

final class SpacesAccessFirestoreGateway {
  const SpacesAccessFirestoreGateway({
    required SpacesAccessDocumentReader documentReader,
  }) : _readDocument = documentReader;

  factory SpacesAccessFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;
    final collection = resolvedFirestore.collection('spaces_access');

    return SpacesAccessFirestoreGateway(
      documentReader: ({required String userId}) async {
        final snapshot = await collection.doc(userId).get();

        if (!snapshot.exists) {
          return null;
        }

        return snapshot.data();
      },
    );
  }

  final SpacesAccessDocumentReader _readDocument;

  Future<SpacesAccessRole?> readRole({required String userId}) async {
    final data = await _readDocument(userId: userId);

    if (data == null) {
      return null;
    }

    return SpacesAccessRole.tryParse(data['role']);
  }
}
