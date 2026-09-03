import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/spaces_bar_board.dart';
import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_board_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpacesBarBoardMapper', () {
    final createdAt = DateTime.utc(2026, 9, 3, 10);

    Map<String, dynamic> validMessageData({
      String text = 'Закреплённое сообщение',
      String lifetime = 'twelveHours',
      String createdByUserId = 'brigadier-1',
      Object? createdAtOverride,
    }) {
      return <String, dynamic>{
        SpacesBarBoardMapper.textField: text,
        SpacesBarBoardMapper.lifetimeField: lifetime,
        SpacesBarBoardMapper.createdByUserIdField: createdByUserId,
        SpacesBarBoardMapper.createdAtField:
            createdAtOverride ?? Timestamp.fromDate(createdAt),
      };
    }

    Map<String, dynamic> validBoardData({
      int schemaVersion = SpacesBarBoardMapper.currentSchemaVersion,
      int revision = 1,
      Map<String, dynamic>? messages,
    }) {
      return <String, dynamic>{
        SpacesBarBoardMapper.schemaVersionField: schemaVersion,
        SpacesBarBoardMapper.revisionField: revision,
        SpacesBarBoardMapper.messagesField:
            messages ?? <String, dynamic>{'message-1': validMessageData()},
        SpacesBarBoardMapper.updatedAtField: Timestamp.fromDate(
          createdAt.add(const Duration(minutes: 1)),
        ),
      };
    }

    test('maps valid persisted board', () {
      final board = SpacesBarBoardMapper.fromMap(
        validBoardData(
          revision: 7,
          messages: <String, dynamic>{
            'message-1': validMessageData(),
            'message-2': validMessageData(
              text: 'До отмены',
              lifetime: 'untilCancelled',
            ),
          },
        ),
      );

      expect(board, isNotNull);
      expect(board!.revision, 7);
      expect(board.messages, hasLength(2));

      final first = board.messages.firstWhere(
        (message) => message.id == 'message-1',
      );

      expect(first.text, 'Закреплённое сообщение');
      expect(first.lifetime, SpacesBarMessageLifetime.twelveHours);
      expect(first.createdByUserId, 'brigadier-1');
      expect(first.createdAt, createdAt);
      expect(first.expiresAt, createdAt.add(const Duration(hours: 12)));
    });

    test('maps empty persisted board', () {
      final board = SpacesBarBoardMapper.fromMap(
        validBoardData(revision: 0, messages: <String, dynamic>{}),
      );

      expect(board, isNotNull);
      expect(board!.messages, isEmpty);
    });

    test('rejects unsupported schema version', () {
      expect(
        SpacesBarBoardMapper.fromMap(validBoardData(schemaVersion: 2)),
        isNull,
      );
    });

    test('rejects unknown board fields', () {
      final data = validBoardData();
      data['unexpected'] = true;

      expect(SpacesBarBoardMapper.fromMap(data), isNull);
    });

    test('rejects malformed message fields', () {
      final message = validMessageData();
      message['unexpected'] = true;

      expect(
        SpacesBarBoardMapper.fromMap(
          validBoardData(messages: <String, dynamic>{'message-1': message}),
        ),
        isNull,
      );
    });

    test('rejects unsupported lifetime', () {
      expect(
        SpacesBarBoardMapper.fromMap(
          validBoardData(
            messages: <String, dynamic>{
              'message-1': validMessageData(lifetime: 'forever'),
            },
          ),
        ),
        isNull,
      );
    });

    test('rejects non timestamp creation time', () {
      expect(
        SpacesBarBoardMapper.fromMap(
          validBoardData(
            messages: <String, dynamic>{
              'message-1': validMessageData(createdAtOverride: '2026-09-03'),
            },
          ),
        ),
        isNull,
      );
    });

    test('rejects non canonical message id', () {
      expect(
        SpacesBarBoardMapper.fromMap(
          validBoardData(
            messages: <String, dynamic>{' message-1 ': validMessageData()},
          ),
        ),
        isNull,
      );
    });

    test('rejects more than three messages', () {
      expect(
        SpacesBarBoardMapper.fromMap(
          validBoardData(
            messages: <String, dynamic>{
              'message-1': validMessageData(),
              'message-2': validMessageData(),
              'message-3': validMessageData(),
              'message-4': validMessageData(),
            },
          ),
        ),
        isNull,
      );
    });

    test('rejects text longer than 250 characters', () {
      expect(
        SpacesBarBoardMapper.fromMap(
          validBoardData(
            messages: <String, dynamic>{
              'message-1': validMessageData(
                text: 'а' * (SpacesBarMessage.maxTextLength + 1),
              ),
            },
          ),
        ),
        isNull,
      );
    });

    test('writes compact versioned board map', () {
      final message = SpacesBarMessage.tryCreate(
        id: 'message-1',
        text: 'Сообщение',
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdByUserId: 'brigadier-1',
        createdAt: createdAt,
      )!;

      final board = SpacesBarBoard.tryCreate(revision: 3, messages: [message])!;

      final data = SpacesBarBoardMapper.toWriteMap(board);

      expect(
        data[SpacesBarBoardMapper.schemaVersionField],
        SpacesBarBoardMapper.currentSchemaVersion,
      );
      expect(data[SpacesBarBoardMapper.revisionField], 3);

      final messages =
          data[SpacesBarBoardMapper.messagesField] as Map<String, dynamic>;

      expect(messages.keys, ['message-1']);

      final persistedMessage = messages['message-1'] as Map<String, dynamic>;

      expect(persistedMessage, <String, dynamic>{
        SpacesBarBoardMapper.textField: 'Сообщение',
        SpacesBarBoardMapper.lifetimeField: 'oneHour',
        SpacesBarBoardMapper.createdByUserIdField: 'brigadier-1',
        SpacesBarBoardMapper.createdAtField: Timestamp.fromDate(createdAt),
      });

      expect(data[SpacesBarBoardMapper.updatedAtField], isA<FieldValue>());
    });

    test('can use server timestamp for newly published message', () {
      final existingMessage = SpacesBarMessage.tryCreate(
        id: 'message-1',
        text: 'Старое сообщение',
        lifetime: SpacesBarMessageLifetime.twelveHours,
        createdByUserId: 'brigadier-1',
        createdAt: createdAt,
      )!;

      final newMessage = SpacesBarMessage.tryCreate(
        id: 'message-2',
        text: 'Новое сообщение',
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdByUserId: 'brigadier-1',
        createdAt: createdAt.add(const Duration(minutes: 5)),
      )!;

      final board = SpacesBarBoard.tryCreate(
        revision: 2,
        messages: [existingMessage, newMessage],
      )!;

      final data = SpacesBarBoardMapper.toWriteMap(
        board,
        serverCreatedAtMessageId: 'message-2',
      );

      final messages =
          data[SpacesBarBoardMapper.messagesField] as Map<String, dynamic>;

      final existingPersisted = messages['message-1'] as Map<String, dynamic>;

      final newPersisted = messages['message-2'] as Map<String, dynamic>;

      expect(
        existingPersisted[SpacesBarBoardMapper.createdAtField],
        Timestamp.fromDate(createdAt),
      );

      expect(
        newPersisted[SpacesBarBoardMapper.createdAtField],
        isA<FieldValue>(),
      );

      expect(data[SpacesBarBoardMapper.updatedAtField], isA<FieldValue>());
    });

    test('rejects unknown server timestamp message id', () {
      final message = SpacesBarMessage.tryCreate(
        id: 'message-1',
        text: 'Сообщение',
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdByUserId: 'brigadier-1',
        createdAt: createdAt,
      )!;

      final board = SpacesBarBoard.tryCreate(revision: 1, messages: [message])!;

      expect(
        () => SpacesBarBoardMapper.toWriteMap(
          board,
          serverCreatedAtMessageId: 'message-999',
        ),
        throwsArgumentError,
      );
    });
  });
}
