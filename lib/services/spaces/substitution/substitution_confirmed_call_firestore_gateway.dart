import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_confirmed_call.dart';
import 'substitution_confirmed_call_mapper.dart';

typedef SubstitutionConfirmedCallDocument = ({
  String id,
  Map<String, dynamic> data,
});

typedef SubstitutionConfirmedCallDocumentsLoader =
    Future<List<SubstitutionConfirmedCallDocument>> Function({
      required String userId,
    });

typedef SubstitutionConfirmedCallDocumentsWatcher =
    Stream<List<SubstitutionConfirmedCallDocument>> Function({
      required String userId,
    });

final class SubstitutionConfirmedCallFirestoreGateway {
  SubstitutionConfirmedCallFirestoreGateway({
    required SubstitutionConfirmedCallDocumentsLoader documentsLoader,
    SubstitutionConfirmedCallDocumentsWatcher? documentsWatcher,
  }) : this._(documentsLoader, documentsWatcher);

  SubstitutionConfirmedCallFirestoreGateway._(
    this._documentsLoader,
    this._documentsWatcher,
  );

  factory SubstitutionConfirmedCallFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final confirmedCallsCollection = resolvedFirestore
        .collection('spaces')
        .doc('substitution')
        .collection('confirmedCalls');

    return SubstitutionConfirmedCallFirestoreGateway(
      documentsLoader: ({required String userId}) async {
        final snapshot = await confirmedCallsCollection
            .where('userId', isEqualTo: userId)
            .get();

        return snapshot.docs
            .map((document) => (id: document.id, data: document.data()))
            .toList(growable: false);
      },
      documentsWatcher: ({required String userId}) {
        return confirmedCallsCollection
            .where('userId', isEqualTo: userId)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map((document) => (id: document.id, data: document.data()))
                  .toList(growable: false),
            );
      },
    );
  }

  final SubstitutionConfirmedCallDocumentsLoader _documentsLoader;

  final SubstitutionConfirmedCallDocumentsWatcher? _documentsWatcher;

  Future<List<SubstitutionConfirmedCall>> loadForUser({
    required String userId,
  }) async {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');

    final documents = await _documentsLoader(userId: normalizedUserId);

    return _mapDocuments(documents);
  }

  Stream<List<SubstitutionConfirmedCall>> watchForUser({
    required String userId,
  }) async* {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');

    final documentsWatcher = _documentsWatcher;

    if (documentsWatcher == null) {
      throw StateError(
        'Substitution confirmed call watcher is not configured.',
      );
    }

    await for (final documents in documentsWatcher(userId: normalizedUserId)) {
      yield _mapDocuments(documents);
    }
  }

  List<SubstitutionConfirmedCall> _mapDocuments(
    List<SubstitutionConfirmedCallDocument> documents,
  ) {
    final calls = <SubstitutionConfirmedCall>[];

    for (final document in documents) {
      final call = SubstitutionConfirmedCallMapper.fromMap(document.data);

      if (call == null) {
        throw StateError(
          'Substitution confirmed call document contains invalid data.',
        );
      }

      if (call.callId != document.id) {
        throw StateError(
          'Substitution confirmed call document id '
          'does not match callId.',
        );
      }

      calls.add(call);
    }

    calls.sort((first, second) {
      final finalizedComparison = second.finalizedAt.compareTo(
        first.finalizedAt,
      );

      if (finalizedComparison != 0) {
        return finalizedComparison;
      }

      return second.revision.compareTo(first.revision);
    });

    return List<SubstitutionConfirmedCall>.unmodifiable(calls);
  }

  static String _normalizeRequired(
    String value, {
    required String argumentName,
  }) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, argumentName, 'must not be empty');
    }

    return normalized;
  }
}
