import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_pending_call.dart';
import 'substitution_pending_call_mapper.dart';

final class SubstitutionPendingCallDocument {
  const SubstitutionPendingCallDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

abstract interface class SubstitutionPendingCallReader {
  Future<List<SubstitutionPendingCallDocument>> readPendingCalls();
}

final class SubstitutionPendingCallFirestoreGateway {
  SubstitutionPendingCallFirestoreGateway(this._reader);

  factory SubstitutionPendingCallFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    return SubstitutionPendingCallFirestoreGateway(
      _FirebaseSubstitutionPendingCallReader(
        firestore ?? FirebaseFirestore.instance,
      ),
    );
  }

  final SubstitutionPendingCallReader _reader;

  Future<List<SubstitutionPendingCall>> loadPendingCalls() async {
    final documents = await _reader.readPendingCalls();

    final result = <SubstitutionPendingCall>[];

    for (final document in documents) {
      final pendingCall = SubstitutionPendingCallMapper.fromMap(document.data);

      if (pendingCall == null) {
        throw StateError(
          'Substitution pending call "${document.id}" '
          'contains invalid data.',
        );
      }

      if (pendingCall.callId != document.id) {
        throw StateError(
          'Substitution pending call document id does not match callId.',
        );
      }

      result.add(pendingCall);
    }

    result.sort((first, second) => first.revision.compareTo(second.revision));

    return List<SubstitutionPendingCall>.unmodifiable(result);
  }
}

final class _FirebaseSubstitutionPendingCallReader
    implements SubstitutionPendingCallReader {
  _FirebaseSubstitutionPendingCallReader(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<SubstitutionPendingCallDocument>> readPendingCalls() async {
    final snapshot = await _firestore
        .collection('spaces')
        .doc('substitution')
        .collection('pendingCalls')
        .get();

    return snapshot.docs
        .map(
          (document) => SubstitutionPendingCallDocument(
            id: document.id,
            data: document.data(),
          ),
        )
        .toList(growable: false);
  }
}
