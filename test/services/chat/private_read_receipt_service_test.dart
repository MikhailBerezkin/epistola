import 'package:epistola/domain/models/private_read_cursor.dart';
import 'package:epistola/services/chat/private_read_receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivateReadReceiptService', () {
    final firstTime = DateTime.utc(2026, 8, 3, 14);
    final secondTime = DateTime.utc(2026, 8, 3, 14, 1);

    PrivateReadCursor cursor({
      required String messageId,
      required DateTime messageCreatedAt,
    }) {
      return PrivateReadCursor.tryCreate(
        messageId: messageId,
        messageCreatedAt: messageCreatedAt,
      )!;
    }

    test('writes a valid read cursor', () async {
      final writes =
          <({String chatId, String userId, PrivateReadCursor cursor})>[];

      final service = PrivateReadReceiptService(
        currentUserIdProvider: () => 'user-1',
        commit:
            ({
              required String chatId,
              required String userId,
              required PrivateReadCursor cursor,
            }) async {
              writes.add((chatId: chatId, userId: userId, cursor: cursor));
            },
      );

      final readCursor = cursor(
        messageId: 'message-10',
        messageCreatedAt: firstTime,
      );

      final result = await service.markRead(
        chatId: 'chat-1',
        cursor: readCursor,
      );

      expect(result, PrivateReadReceiptWriteResult.written);
      expect(writes, hasLength(1));
      expect(writes.single.chatId, 'chat-1');
      expect(writes.single.userId, 'user-1');
      expect(writes.single.cursor, readCursor);
    });

    test('normalizes chat and current user IDs', () async {
      String? committedChatId;
      String? committedUserId;

      final service = PrivateReadReceiptService(
        currentUserIdProvider: () => '  user-1  ',
        commit:
            ({
              required String chatId,
              required String userId,
              required PrivateReadCursor cursor,
            }) async {
              committedChatId = chatId;
              committedUserId = userId;
            },
      );

      await service.markRead(
        chatId: '  chat-1  ',
        cursor: cursor(messageId: 'message-10', messageCreatedAt: firstTime),
      );

      expect(committedChatId, 'chat-1');
      expect(committedUserId, 'user-1');
    });

    test('skips when the current user is unavailable', () async {
      var commitCount = 0;

      final service = PrivateReadReceiptService(
        currentUserIdProvider: () => null,
        commit:
            ({
              required String chatId,
              required String userId,
              required PrivateReadCursor cursor,
            }) async {
              commitCount++;
            },
      );

      final result = await service.markRead(
        chatId: 'chat-1',
        cursor: cursor(messageId: 'message-10', messageCreatedAt: firstTime),
      );

      expect(result, PrivateReadReceiptWriteResult.skippedUnauthenticated);
      expect(commitCount, 0);
    });

    test('skips the same cursor after a successful write', () async {
      var commitCount = 0;

      final service = PrivateReadReceiptService(
        currentUserIdProvider: () => 'user-1',
        commit:
            ({
              required String chatId,
              required String userId,
              required PrivateReadCursor cursor,
            }) async {
              commitCount++;
            },
      );

      final readCursor = cursor(
        messageId: 'message-10',
        messageCreatedAt: firstTime,
      );

      await service.markRead(chatId: 'chat-1', cursor: readCursor);

      final secondResult = await service.markRead(
        chatId: 'chat-1',
        cursor: readCursor,
      );

      expect(secondResult, PrivateReadReceiptWriteResult.skippedNotAdvanced);
      expect(commitCount, 1);
    });

    test('skips a cursor older than the committed cursor', () async {
      var commitCount = 0;

      final service = PrivateReadReceiptService(
        currentUserIdProvider: () => 'user-1',
        commit:
            ({
              required String chatId,
              required String userId,
              required PrivateReadCursor cursor,
            }) async {
              commitCount++;
            },
      );

      await service.markRead(
        chatId: 'chat-1',
        cursor: cursor(messageId: 'message-20', messageCreatedAt: secondTime),
      );

      final result = await service.markRead(
        chatId: 'chat-1',
        cursor: cursor(messageId: 'message-10', messageCreatedAt: firstTime),
      );

      expect(result, PrivateReadReceiptWriteResult.skippedNotAdvanced);
      expect(commitCount, 1);
    });

    test('writes a cursor newer than the committed cursor', () async {
      final committedMessageIds = <String>[];

      final service = PrivateReadReceiptService(
        currentUserIdProvider: () => 'user-1',
        commit:
            ({
              required String chatId,
              required String userId,
              required PrivateReadCursor cursor,
            }) async {
              committedMessageIds.add(cursor.messageId);
            },
      );

      await service.markRead(
        chatId: 'chat-1',
        cursor: cursor(messageId: 'message-10', messageCreatedAt: firstTime),
      );

      final result = await service.markRead(
        chatId: 'chat-1',
        cursor: cursor(messageId: 'message-20', messageCreatedAt: secondTime),
      );

      expect(result, PrivateReadReceiptWriteResult.written);
      expect(committedMessageIds, ['message-10', 'message-20']);
    });

    test('does not cache a failed write', () async {
      var attemptCount = 0;

      final service = PrivateReadReceiptService(
        currentUserIdProvider: () => 'user-1',
        commit:
            ({
              required String chatId,
              required String userId,
              required PrivateReadCursor cursor,
            }) async {
              attemptCount++;

              if (attemptCount == 1) {
                throw StateError('Temporary write failure');
              }
            },
      );

      final readCursor = cursor(
        messageId: 'message-10',
        messageCreatedAt: firstTime,
      );

      await expectLater(
        service.markRead(chatId: 'chat-1', cursor: readCursor),
        throwsStateError,
      );

      final secondResult = await service.markRead(
        chatId: 'chat-1',
        cursor: readCursor,
      );

      expect(secondResult, PrivateReadReceiptWriteResult.written);
      expect(attemptCount, 2);
    });

    test('rejects an invalid chat ID', () async {
      final service = PrivateReadReceiptService(
        currentUserIdProvider: () => 'user-1',
        commit:
            ({
              required String chatId,
              required String userId,
              required PrivateReadCursor cursor,
            }) async {},
      );

      await expectLater(
        service.markRead(
          chatId: 'chat/1',
          cursor: cursor(messageId: 'message-10', messageCreatedAt: firstTime),
        ),
        throwsArgumentError,
      );
    });
  });
}
