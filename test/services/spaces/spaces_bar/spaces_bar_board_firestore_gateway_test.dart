import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_board_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpacesBarBoardFirestoreGateway', () {
    final createdAt = DateTime.utc(2026, 9, 3, 10);

    test('missing board returns empty board with one read', () async {
      var readCount = 0;

      final gateway = SpacesBarBoardFirestoreGateway(
        documentReader: () async {
          readCount += 1;
          return null;
        },
      );

      final board = await gateway.load();

      expect(readCount, 1);
      expect(board.revision, 0);
      expect(board.messages, isEmpty);
    });

    test('loads board with one document read', () async {
      var readCount = 0;

      final gateway = SpacesBarBoardFirestoreGateway(
        documentReader: () async {
          readCount += 1;

          return <String, dynamic>{
            'schemaVersion': 1,
            'revision': 7,
            'messages': <String, dynamic>{
              'message-1': <String, dynamic>{
                'text': 'Закреплённое сообщение',
                'lifetime': 'twelveHours',
                'createdByUserId': 'brigadier-1',
                'createdAt': Timestamp.fromDate(createdAt),
              },
            },
            'updatedAt': Timestamp.fromDate(
              createdAt.add(const Duration(minutes: 1)),
            ),
          };
        },
      );

      final board = await gateway.load();

      expect(readCount, 1);
      expect(board.revision, 7);
      expect(board.messages, hasLength(1));
      expect(board.messages.single.id, 'message-1');
      expect(board.messages.single.text, 'Закреплённое сообщение');
    });

    test('rejects malformed persisted board', () async {
      var readCount = 0;

      final gateway = SpacesBarBoardFirestoreGateway(
        documentReader: () async {
          readCount += 1;

          return <String, dynamic>{
            'schemaVersion': 999,
            'revision': 1,
            'messages': <String, dynamic>{},
            'updatedAt': Timestamp.fromDate(createdAt),
          };
        },
      );

      await expectLater(gateway.load(), throwsStateError);

      expect(readCount, 1);
    });
  });
}
