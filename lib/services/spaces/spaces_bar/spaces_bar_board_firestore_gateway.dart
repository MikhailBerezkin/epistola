import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/spaces_bar_board.dart';
import 'spaces_bar_board_mapper.dart';

typedef SpacesBarBoardDocumentReader = Future<Map<String, dynamic>?> Function();

typedef SpacesBarBoardDocumentWatcher =
    Stream<Map<String, dynamic>?> Function();

final class SpacesBarBoardFirestoreGateway {
  SpacesBarBoardFirestoreGateway({
    required SpacesBarBoardDocumentReader documentReader,
    SpacesBarBoardDocumentWatcher? documentWatcher,
  }) : _readDocument = documentReader,
       _watchDocument = documentWatcher;

  factory SpacesBarBoardFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final boardReference = resolvedFirestore
        .collection('spaces')
        .doc('spacesBar');

    return SpacesBarBoardFirestoreGateway(
      documentReader: () async {
        final snapshot = await boardReference.get();

        if (!snapshot.exists) {
          return null;
        }

        return snapshot.data();
      },
      documentWatcher: () {
        return boardReference.snapshots().map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }

          return snapshot.data();
        });
      },
    );
  }

  final SpacesBarBoardDocumentReader _readDocument;
  final SpacesBarBoardDocumentWatcher? _watchDocument;

  Future<SpacesBarBoard> load() async {
    final data = await _readDocument();

    return _mapDocument(data);
  }

  Stream<SpacesBarBoard> watch() async* {
    final watchDocument = _watchDocument;

    if (watchDocument == null) {
      throw StateError('SpacesBar board watcher is not configured.');
    }

    await for (final data in watchDocument()) {
      yield _mapDocument(data);
    }
  }

  SpacesBarBoard _mapDocument(Map<String, dynamic>? data) {
    if (data == null) {
      return SpacesBarBoard.empty();
    }

    final board = SpacesBarBoardMapper.fromMap(data);

    if (board == null) {
      throw StateError('SpacesBar board contains invalid data.');
    }

    return board;
  }
}
