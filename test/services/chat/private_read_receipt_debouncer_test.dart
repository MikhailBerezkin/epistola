import 'package:epistola/domain/models/private_read_cursor.dart';
import 'package:epistola/services/chat/private_read_receipt_debouncer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivateReadReceiptDebouncer', () {
    final firstTime = DateTime.utc(2026, 8, 3, 15);
    final secondTime = DateTime.utc(2026, 8, 3, 15, 1);

    PrivateReadCursor cursor({
      required String messageId,
      required DateTime messageCreatedAt,
    }) {
      return PrivateReadCursor.tryCreate(
        messageId: messageId,
        messageCreatedAt: messageCreatedAt,
      )!;
    }

    test('commits a scheduled cursor after the delay', () async {
      final committedCursors = <PrivateReadCursor>[];

      final debouncer = PrivateReadReceiptDebouncer(
        delay: const Duration(milliseconds: 20),
        commit: (cursor) async {
          committedCursors.add(cursor);
        },
      );

      final readCursor = cursor(
        messageId: 'message-1',
        messageCreatedAt: firstTime,
      );

      debouncer.schedule(readCursor);

      expect(committedCursors, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(committedCursors, [readCursor]);

      debouncer.dispose();
    });

    test('commits only the newest pending cursor', () async {
      final committedMessageIds = <String>[];

      final debouncer = PrivateReadReceiptDebouncer(
        delay: const Duration(milliseconds: 20),
        commit: (cursor) async {
          committedMessageIds.add(cursor.messageId);
        },
      );

      debouncer.schedule(
        cursor(messageId: 'message-1', messageCreatedAt: firstTime),
      );

      debouncer.schedule(
        cursor(messageId: 'message-2', messageCreatedAt: secondTime),
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(committedMessageIds, ['message-2']);

      debouncer.dispose();
    });

    test('does not replace a newer cursor with an older one', () async {
      final committedMessageIds = <String>[];

      final debouncer = PrivateReadReceiptDebouncer(
        delay: const Duration(milliseconds: 20),
        commit: (cursor) async {
          committedMessageIds.add(cursor.messageId);
        },
      );

      debouncer.schedule(
        cursor(messageId: 'message-2', messageCreatedAt: secondTime),
      );

      debouncer.schedule(
        cursor(messageId: 'message-1', messageCreatedAt: firstTime),
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(committedMessageIds, ['message-2']);

      debouncer.dispose();
    });

    test('flushNow commits immediately without a duplicate', () async {
      final committedMessageIds = <String>[];

      final debouncer = PrivateReadReceiptDebouncer(
        delay: const Duration(milliseconds: 100),
        commit: (cursor) async {
          committedMessageIds.add(cursor.messageId);
        },
      );

      debouncer.schedule(
        cursor(messageId: 'message-1', messageCreatedAt: firstTime),
      );

      await debouncer.flushNow();

      expect(committedMessageIds, ['message-1']);

      await Future<void>.delayed(const Duration(milliseconds: 140));

      expect(committedMessageIds, ['message-1']);

      debouncer.dispose();
    });

    test('reports a write error and accepts a later cursor', () async {
      final errors = <Object>[];
      final committedMessageIds = <String>[];

      var attemptCount = 0;

      final debouncer = PrivateReadReceiptDebouncer(
        delay: const Duration(milliseconds: 20),
        onError: (error, _) {
          errors.add(error);
        },
        commit: (cursor) async {
          attemptCount++;

          if (attemptCount == 1) {
            throw StateError('Temporary write failure');
          }

          committedMessageIds.add(cursor.messageId);
        },
      );

      debouncer.schedule(
        cursor(messageId: 'message-1', messageCreatedAt: firstTime),
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));

      debouncer.schedule(
        cursor(messageId: 'message-2', messageCreatedAt: secondTime),
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      expect(committedMessageIds, ['message-2']);

      debouncer.dispose();
    });

    test('dispose cancels a pending cursor', () async {
      var commitCount = 0;

      final debouncer = PrivateReadReceiptDebouncer(
        delay: const Duration(milliseconds: 20),
        commit: (_) async {
          commitCount++;
        },
      );

      debouncer.schedule(
        cursor(messageId: 'message-1', messageCreatedAt: firstTime),
      );

      debouncer.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(commitCount, 0);
    });

    test('rejects a negative debounce delay', () {
      expect(
        () => PrivateReadReceiptDebouncer(
          delay: const Duration(milliseconds: -1),
          commit: (_) async {},
        ),
        throwsArgumentError,
      );
    });
  });
}
