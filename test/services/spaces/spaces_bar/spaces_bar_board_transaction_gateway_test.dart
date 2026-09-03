import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_board_transaction_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpacesBarBoardTransactionGateway.publish', () {
    final now = DateTime.utc(2026, 9, 3, 10);

    test('first publication creates revision one', () async {
      final context = _FakeTransactionContext(boardData: null);
      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      final receipt = await gateway.publish(
        text: ' Первое сообщение ',
        lifetime: SpacesBarMessageLifetime.twelveHours,
        createdByUserId: ' brigadier-1 ',
      );

      expect(runner.runCount, 1);

      expect(receipt.revision, 1);
      expect(receipt.messageId, '1');

      expect(context.readCount, 1);
      expect(context.writes, hasLength(1));

      final written = context.writes.single;

      expect(written['schemaVersion'], 1);
      expect(written['revision'], 1);

      final messages = written['messages'] as Map<String, dynamic>;

      expect(messages.keys, ['1']);

      final message = messages['1'] as Map<String, dynamic>;

      expect(message['text'], 'Первое сообщение');
      expect(message['lifetime'], 'twelveHours');
      expect(message['createdByUserId'], 'brigadier-1');
      expect(message['createdAt'], isA<FieldValue>());

      expect(written['updatedAt'], isA<FieldValue>());
    });

    test('existing revision is incremented', () async {
      final existingCreatedAt = now.subtract(const Duration(hours: 1));

      final context = _FakeTransactionContext(
        boardData: _boardData(
          revision: 7,
          updatedAt: existingCreatedAt,
          messages: <String, dynamic>{
            '7': _messageData(
              text: 'Старое сообщение',
              lifetime: 'twelveHours',
              createdAt: existingCreatedAt,
            ),
          },
        ),
      );

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      final receipt = await gateway.publish(
        text: 'Новое сообщение',
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdByUserId: 'owner-1',
      );

      expect(receipt.revision, 8);
      expect(receipt.messageId, '8');

      final written = context.writes.single;

      expect(written['revision'], 8);

      final messages = written['messages'] as Map<String, dynamic>;

      expect(messages.keys, containsAll(<String>['7', '8']));
      expect(messages, hasLength(2));

      final existing = messages['7'] as Map<String, dynamic>;
      final added = messages['8'] as Map<String, dynamic>;

      expect(existing['createdAt'], Timestamp.fromDate(existingCreatedAt));

      expect(added['createdAt'], isA<FieldValue>());
      expect(added['text'], 'Новое сообщение');
      expect(added['lifetime'], 'oneHour');
      expect(added['createdByUserId'], 'owner-1');
    });

    test('expired messages are pruned before publication', () async {
      final expiredCreatedAt = now.subtract(const Duration(hours: 13));
      final activeCreatedAt = now.subtract(const Duration(hours: 1));

      final context = _FakeTransactionContext(
        boardData: _boardData(
          revision: 4,
          updatedAt: activeCreatedAt,
          messages: <String, dynamic>{
            '1': _messageData(
              text: 'Истёкшее',
              lifetime: 'twelveHours',
              createdAt: expiredCreatedAt,
            ),
            '4': _messageData(
              text: 'Активное',
              lifetime: 'twentyFourHours',
              createdAt: activeCreatedAt,
            ),
          },
        ),
      );

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      final receipt = await gateway.publish(
        text: 'Новое',
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdByUserId: 'brigadier-1',
      );

      expect(receipt.revision, 5);
      expect(receipt.messageId, '5');

      final written = context.writes.single;

      final messages = written['messages'] as Map<String, dynamic>;

      expect(messages.containsKey('1'), isFalse);
      expect(messages.containsKey('4'), isTrue);
      expect(messages.containsKey('5'), isTrue);
      expect(messages, hasLength(2));
    });

    test('three active messages reject publication', () async {
      final createdAt = now.subtract(const Duration(minutes: 5));

      final context = _FakeTransactionContext(
        boardData: _boardData(
          revision: 3,
          updatedAt: createdAt,
          messages: <String, dynamic>{
            '1': _messageData(
              text: 'Первое',
              lifetime: 'untilCancelled',
              createdAt: createdAt,
            ),
            '2': _messageData(
              text: 'Второе',
              lifetime: 'twentyFourHours',
              createdAt: createdAt,
            ),
            '3': _messageData(
              text: 'Третье',
              lifetime: 'twelveHours',
              createdAt: createdAt,
            ),
          },
        ),
      );

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      await expectLater(
        gateway.publish(
          text: 'Четвёртое',
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdByUserId: 'brigadier-1',
        ),
        throwsA(isA<SpacesBarBoardCapacityException>()),
      );

      expect(context.readCount, 1);
      expect(context.writes, isEmpty);
    });

    test('malformed persisted board rejects publication', () async {
      final context = _FakeTransactionContext(
        boardData: <String, dynamic>{
          'schemaVersion': 999,
          'revision': 1,
          'messages': <String, dynamic>{},
          'updatedAt': Timestamp.fromDate(now),
        },
      );

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      await expectLater(
        gateway.publish(
          text: 'Сообщение',
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdByUserId: 'brigadier-1',
        ),
        throwsStateError,
      );

      expect(context.readCount, 1);
      expect(context.writes, isEmpty);
    });

    test('invalid text is rejected before transaction', () async {
      final context = _FakeTransactionContext(boardData: null);

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      expect(
        () => gateway.publish(
          text: '   ',
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdByUserId: 'brigadier-1',
        ),
        throwsArgumentError,
      );

      expect(runner.runCount, 0);
      expect(context.readCount, 0);
      expect(context.writes, isEmpty);
    });

    test('text longer than 250 is rejected before transaction', () async {
      final context = _FakeTransactionContext(boardData: null);

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      expect(
        () => gateway.publish(
          text: 'а' * (SpacesBarMessage.maxTextLength + 1),
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdByUserId: 'brigadier-1',
        ),
        throwsArgumentError,
      );

      expect(runner.runCount, 0);
      expect(context.readCount, 0);
      expect(context.writes, isEmpty);
    });

    test('invalid publisher id is rejected before transaction', () async {
      final context = _FakeTransactionContext(boardData: null);

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      expect(
        () => gateway.publish(
          text: 'Сообщение',
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdByUserId: 'bad/user',
        ),
        throwsArgumentError,
      );

      expect(runner.runCount, 0);
      expect(context.readCount, 0);
      expect(context.writes, isEmpty);
    });

    test('revision conflict rejects publication without write', () async {
      final createdAt = now.subtract(const Duration(minutes: 10));

      final context = _FakeTransactionContext(
        boardData: _boardData(
          revision: 1,
          updatedAt: createdAt,
          messages: <String, dynamic>{
            '2': _messageData(
              text: 'Конфликтующая запись',
              lifetime: 'untilCancelled',
              createdAt: createdAt,
            ),
          },
        ),
      );

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      await expectLater(
        gateway.publish(
          text: 'Новое сообщение',
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdByUserId: 'brigadier-1',
        ),
        throwsStateError,
      );

      expect(context.writes, isEmpty);
    });
  });

  group('SpacesBarBoardTransactionGateway.deleteMessage', () {
    final now = DateTime.utc(2026, 9, 3, 10);

    test('deletes selected message and increments revision', () async {
      final createdAt = now.subtract(const Duration(hours: 1));

      final context = _FakeTransactionContext(
        boardData: _boardData(
          revision: 7,
          updatedAt: createdAt,
          messages: <String, dynamic>{
            '5': _messageData(
              text: 'Оставить',
              lifetime: 'twentyFourHours',
              createdAt: createdAt,
            ),
            '6': _messageData(
              text: 'Удалить',
              lifetime: 'untilCancelled',
              createdAt: createdAt,
            ),
          },
        ),
      );

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      final deleted = await gateway.deleteMessage(messageId: '6');

      expect(deleted, isTrue);
      expect(context.readCount, 1);
      expect(context.writes, hasLength(1));

      final written = context.writes.single;

      expect(written['revision'], 8);

      final messages = written['messages'] as Map<String, dynamic>;

      expect(messages.keys, ['5']);
      expect(messages.containsKey('6'), isFalse);

      final remaining = messages['5'] as Map<String, dynamic>;

      expect(remaining['createdAt'], Timestamp.fromDate(createdAt));

      expect(written['updatedAt'], isA<FieldValue>());
    });

    test('deleting last message leaves empty board', () async {
      final createdAt = now.subtract(const Duration(minutes: 5));

      final context = _FakeTransactionContext(
        boardData: _boardData(
          revision: 3,
          updatedAt: createdAt,
          messages: <String, dynamic>{
            '3': _messageData(
              text: 'Единственное',
              lifetime: 'untilCancelled',
              createdAt: createdAt,
            ),
          },
        ),
      );

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      final deleted = await gateway.deleteMessage(messageId: '3');

      expect(deleted, isTrue);

      final written = context.writes.single;

      expect(written['revision'], 4);

      final messages = written['messages'] as Map<String, dynamic>;

      expect(messages, isEmpty);
    });

    test('expired messages are pruned during deletion', () async {
      final activeCreatedAt = now.subtract(const Duration(hours: 1));
      final expiredCreatedAt = now.subtract(const Duration(hours: 13));

      final context = _FakeTransactionContext(
        boardData: _boardData(
          revision: 9,
          updatedAt: activeCreatedAt,
          messages: <String, dynamic>{
            '4': _messageData(
              text: 'Истёкшее',
              lifetime: 'twelveHours',
              createdAt: expiredCreatedAt,
            ),
            '8': _messageData(
              text: 'Удалить',
              lifetime: 'untilCancelled',
              createdAt: activeCreatedAt,
            ),
            '9': _messageData(
              text: 'Оставить',
              lifetime: 'twentyFourHours',
              createdAt: activeCreatedAt,
            ),
          },
        ),
      );

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      final deleted = await gateway.deleteMessage(messageId: '8');

      expect(deleted, isTrue);

      final written = context.writes.single;

      expect(written['revision'], 10);

      final messages = written['messages'] as Map<String, dynamic>;

      expect(messages.keys, ['9']);
      expect(messages.containsKey('4'), isFalse);
      expect(messages.containsKey('8'), isFalse);
    });

    test('missing message returns false without write', () async {
      final createdAt = now.subtract(const Duration(minutes: 5));

      final context = _FakeTransactionContext(
        boardData: _boardData(
          revision: 2,
          updatedAt: createdAt,
          messages: <String, dynamic>{
            '2': _messageData(
              text: 'Сообщение',
              lifetime: 'untilCancelled',
              createdAt: createdAt,
            ),
          },
        ),
      );

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      final deleted = await gateway.deleteMessage(messageId: '999');

      expect(deleted, isFalse);
      expect(context.readCount, 1);
      expect(context.writes, isEmpty);
    });

    test('missing board returns false without write', () async {
      final context = _FakeTransactionContext(boardData: null);

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      final deleted = await gateway.deleteMessage(messageId: '1');

      expect(deleted, isFalse);
      expect(context.readCount, 1);
      expect(context.writes, isEmpty);
    });

    test('invalid message id is rejected before transaction', () {
      final context = _FakeTransactionContext(boardData: null);

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      expect(
        () => gateway.deleteMessage(messageId: 'bad/id'),
        throwsArgumentError,
      );

      expect(runner.runCount, 0);
      expect(context.readCount, 0);
      expect(context.writes, isEmpty);
    });

    test('malformed board rejects deletion', () async {
      final context = _FakeTransactionContext(
        boardData: <String, dynamic>{
          'schemaVersion': 999,
          'revision': 1,
          'messages': <String, dynamic>{},
          'updatedAt': Timestamp.fromDate(now),
        },
      );

      final runner = _FakeTransactionRunner(context);

      final gateway = SpacesBarBoardTransactionGateway(
        transactionRunner: runner,
        clock: () => now,
      );

      await expectLater(
        gateway.deleteMessage(messageId: '1'),
        throwsStateError,
      );

      expect(context.readCount, 1);
      expect(context.writes, isEmpty);
    });
  });
}

Map<String, dynamic> _boardData({
  required int revision,
  required DateTime updatedAt,
  required Map<String, dynamic> messages,
}) {
  return <String, dynamic>{
    'schemaVersion': 1,
    'revision': revision,
    'messages': messages,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}

Map<String, dynamic> _messageData({
  required String text,
  required String lifetime,
  required DateTime createdAt,
}) {
  return <String, dynamic>{
    'text': text,
    'lifetime': lifetime,
    'createdByUserId': 'brigadier-1',
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

final class _FakeTransactionRunner implements SpacesBarBoardTransactionRunner {
  _FakeTransactionRunner(this.context);

  final _FakeTransactionContext context;

  int runCount = 0;

  @override
  Future<T> run<T>(
    Future<T> Function(SpacesBarBoardTransactionContext context) action,
  ) {
    runCount += 1;

    return action(context);
  }
}

final class _FakeTransactionContext
    implements SpacesBarBoardTransactionContext {
  _FakeTransactionContext({required this.boardData});

  final Map<String, dynamic>? boardData;

  int readCount = 0;
  final List<Map<String, dynamic>> writes = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> readBoard() async {
    readCount += 1;

    return boardData;
  }

  @override
  void setBoard(Map<String, dynamic> data) {
    writes.add(data);
  }
}
