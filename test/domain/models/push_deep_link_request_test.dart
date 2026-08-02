import 'package:epistola/domain/models/push_deep_link_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushDeepLinkRequest', () {
    test('reads chatId from remote message data', () {
      final request = PushDeepLinkRequest.fromRemoteData({
        'chatId': 'private-chat-1',
      });

      expect(request, isNotNull);
      expect(request?.chatId, 'private-chat-1');
    });

    test('reads chatId from local notification payload', () {
      final request = PushDeepLinkRequest.fromLocalPayload('group-chat-1');

      expect(request, isNotNull);
      expect(request?.chatId, 'group-chat-1');
    });

    test('normalizes surrounding whitespace', () {
      final request = PushDeepLinkRequest.tryParseChatId('  private-chat-1  ');

      expect(request?.chatId, 'private-chat-1');
    });

    test('rejects a missing or non-string chatId', () {
      expect(PushDeepLinkRequest.tryParseChatId(null), isNull);
      expect(PushDeepLinkRequest.tryParseChatId(123), isNull);
      expect(PushDeepLinkRequest.fromRemoteData(const {}), isNull);
    });

    test('rejects an empty chatId', () {
      expect(PushDeepLinkRequest.tryParseChatId(''), isNull);
      expect(PushDeepLinkRequest.tryParseChatId('   '), isNull);
    });

    test('rejects a chatId containing a slash', () {
      expect(
        PushDeepLinkRequest.tryParseChatId('chats/private-chat-1'),
        isNull,
      );
    });

    test('uses value equality based on chatId', () {
      final first = PushDeepLinkRequest.tryParseChatId('chat-1');
      final second = PushDeepLinkRequest.tryParseChatId('chat-1');
      final different = PushDeepLinkRequest.tryParseChatId('chat-2');

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });

    test('provides a readable string representation', () {
      final request = PushDeepLinkRequest.tryParseChatId('chat-1');

      expect(request.toString(), 'PushDeepLinkRequest(chatId: chat-1)');
    });
  });
}
