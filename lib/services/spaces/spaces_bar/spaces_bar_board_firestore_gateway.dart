import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/spaces_bar_board.dart';
import 'spaces_bar_board_mapper.dart';

typedef SpacesBarBoardDocumentReader = Future<Map<String, dynamic>?> Function();

final class SpacesBarBoardFirestoreGateway {
  SpacesBarBoardFirestoreGateway({
    required SpacesBarBoardDocumentReader documentReader,
  }) : _readDocument = documentReader;

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
    );
  }

  final SpacesBarBoardDocumentReader _readDocument;

  Future<SpacesBarBoard> load() async {
    final data = await _readDocument();

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
