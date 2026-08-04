import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/services/chat/private_read_cursor_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivateReadCursorMapper', () {
    final cursorTime = DateTime.utc(2026, 8, 3, 13, 45);

    test('reads a valid cursor for the requested user', () {
      final cursor = PrivateReadCursorMapper.fromChatData(
        chatData: {
          'privateReadState': {
            'user-2': {
              'messageId': 'message-20',
              'messageCreatedAt': Timestamp.fromDate(cursorTime),
              'readAt': Timestamp.fromDate(
                cursorTime.add(const Duration(seconds: 2)),
              ),
            },
          },
        },
        userId: 'user-2',
      );

      expect(cursor, isNotNull);
      expect(cursor!.messageId, 'message-20');
      expect(cursor.messageCreatedAt, cursorTime);
    });

    test('normalizes surrounding user ID whitespace', () {
      final cursor = PrivateReadCursorMapper.fromChatData(
        chatData: {
          'privateReadState': {
            'user-2': {
              'messageId': 'message-20',
              'messageCreatedAt': Timestamp.fromDate(cursorTime),
            },
          },
        },
        userId: '  user-2  ',
      );

      expect(cursor, isNotNull);
      expect(cursor!.messageId, 'message-20');
    });

    test('returns null when private read state is missing', () {
      final cursor = PrivateReadCursorMapper.fromChatData(
        chatData: const {},
        userId: 'user-2',
      );

      expect(cursor, isNull);
    });

    test('returns null when the requested user has no state', () {
      final cursor = PrivateReadCursorMapper.fromChatData(
        chatData: {
          'privateReadState': {
            'user-1': {
              'messageId': 'message-10',
              'messageCreatedAt': Timestamp.fromDate(cursorTime),
            },
          },
        },
        userId: 'user-2',
      );

      expect(cursor, isNull);
    });

    test('returns null for a malformed user read state', () {
      final cursor = PrivateReadCursorMapper.fromChatData(
        chatData: {
          'privateReadState': {'user-2': 'invalid-state'},
        },
        userId: 'user-2',
      );

      expect(cursor, isNull);
    });

    test('returns null when message ID is invalid', () {
      final cursor = PrivateReadCursorMapper.fromChatData(
        chatData: {
          'privateReadState': {
            'user-2': {
              'messageId': 'message/20',
              'messageCreatedAt': Timestamp.fromDate(cursorTime),
            },
          },
        },
        userId: 'user-2',
      );

      expect(cursor, isNull);
    });

    test('returns null when message timestamp is invalid', () {
      final cursor = PrivateReadCursorMapper.fromChatData(
        chatData: {
          'privateReadState': {
            'user-2': {
              'messageId': 'message-20',
              'messageCreatedAt': '2026-08-03T13:45:00Z',
            },
          },
        },
        userId: 'user-2',
      );

      expect(cursor, isNull);
    });

    test('returns null for an invalid user ID', () {
      final cursor = PrivateReadCursorMapper.fromChatData(
        chatData: {
          'privateReadState': {
            'user-2': {
              'messageId': 'message-20',
              'messageCreatedAt': Timestamp.fromDate(cursorTime),
            },
          },
        },
        userId: 'user/2',
      );

      expect(cursor, isNull);
    });
  });
}
