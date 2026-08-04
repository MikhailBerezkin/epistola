import 'package:epistola/domain/models/private_read_cursor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivateReadCursor', () {
    final cursorTime = DateTime.utc(2026, 8, 3, 12, 30);

    test('creates a cursor from valid values', () {
      final cursor = PrivateReadCursor.tryCreate(
        messageId: 'message-2',
        messageCreatedAt: cursorTime,
      );

      expect(cursor, isNotNull);
      expect(cursor!.messageId, 'message-2');
      expect(cursor.messageCreatedAt, cursorTime);
    });

    test('normalizes surrounding message ID whitespace', () {
      final cursor = PrivateReadCursor.tryCreate(
        messageId: '  message-2  ',
        messageCreatedAt: cursorTime,
      );

      expect(cursor, isNotNull);
      expect(cursor!.messageId, 'message-2');
    });

    test('rejects an empty message ID', () {
      final cursor = PrivateReadCursor.tryCreate(
        messageId: '   ',
        messageCreatedAt: cursorTime,
      );

      expect(cursor, isNull);
    });

    test('rejects a message ID containing a slash', () {
      final cursor = PrivateReadCursor.tryCreate(
        messageId: 'message/2',
        messageCreatedAt: cursorTime,
      );

      expect(cursor, isNull);
    });

    test('rejects a missing message timestamp', () {
      final cursor = PrivateReadCursor.tryCreate(
        messageId: 'message-2',
        messageCreatedAt: null,
      );

      expect(cursor, isNull);
    });

    test('covers an older message', () {
      final cursor = PrivateReadCursor.tryCreate(
        messageId: 'message-2',
        messageCreatedAt: cursorTime,
      )!;

      final result = cursor.covers(
        messageId: 'message-1',
        messageCreatedAt: cursorTime.subtract(const Duration(seconds: 1)),
      );

      expect(result, isTrue);
    });

    test('covers the cursor message itself', () {
      final cursor = PrivateReadCursor.tryCreate(
        messageId: 'message-2',
        messageCreatedAt: cursorTime,
      )!;

      final result = cursor.covers(
        messageId: 'message-2',
        messageCreatedAt: cursorTime,
      );

      expect(result, isTrue);
    });

    test('does not cover a newer message', () {
      final cursor = PrivateReadCursor.tryCreate(
        messageId: 'message-2',
        messageCreatedAt: cursorTime,
      )!;

      final result = cursor.covers(
        messageId: 'message-3',
        messageCreatedAt: cursorTime.add(const Duration(seconds: 1)),
      );

      expect(result, isFalse);
    });

    test('does not cover another message with the same timestamp', () {
      final cursor = PrivateReadCursor.tryCreate(
        messageId: 'message-2',
        messageCreatedAt: cursorTime,
      )!;

      final result = cursor.covers(
        messageId: 'message-1',
        messageCreatedAt: cursorTime,
      );

      expect(result, isFalse);
    });

    test('supports value equality', () {
      final first = PrivateReadCursor.tryCreate(
        messageId: 'message-2',
        messageCreatedAt: cursorTime,
      );

      final second = PrivateReadCursor.tryCreate(
        messageId: 'message-2',
        messageCreatedAt: cursorTime.toLocal(),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
