import 'package:epistola/domain/models/push_deep_link_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushDeepLinkRequest', () {
    test('reads legacy chatId from remote message data', () {
      final request = PushDeepLinkRequest.fromRemoteData({
        'chatId': 'private-chat-1',
      });

      expect(request, isNotNull);
      expect(request?.targetType, PushDeepLinkTargetType.chat);
      expect(request?.chatId, 'private-chat-1');
      expect(request?.spacesBarMessageId, isNull);
    });

    test('reads explicitly typed chat target from remote data', () {
      final request = PushDeepLinkRequest.fromRemoteData({
        'deepLinkType': 'chat',
        'chatId': 'group-chat-1',
      });

      expect(request?.targetType, PushDeepLinkTargetType.chat);
      expect(request?.chatId, 'group-chat-1');
    });

    test('reads SpacesBar target from remote data', () {
      final request = PushDeepLinkRequest.fromRemoteData({
        'deepLinkType': 'spacesBar',
        'spacesBarMessageId': '42',
      });

      expect(request, isNotNull);
      expect(request?.targetType, PushDeepLinkTargetType.spacesBar);
      expect(request?.chatId, isNull);
      expect(request?.spacesBarMessageId, '42');
    });

    test('reads legacy chatId from local notification payload', () {
      final request = PushDeepLinkRequest.fromLocalPayload('group-chat-1');

      expect(request?.targetType, PushDeepLinkTargetType.chat);
      expect(request?.chatId, 'group-chat-1');
    });

    test('round-trips typed chat local payload', () {
      final original = PushDeepLinkRequest.tryParseChatId('chat-1')!;

      final restored = PushDeepLinkRequest.fromLocalPayload(
        original.toLocalPayload(),
      );

      expect(restored, original);
    });

    test('round-trips SpacesBar local payload', () {
      final original = PushDeepLinkRequest.tryParseSpacesBarMessageId('17')!;

      final restored = PushDeepLinkRequest.fromLocalPayload(
        original.toLocalPayload(),
      );

      expect(restored, original);
    });

    test('normalizes surrounding whitespace', () {
      final chatRequest = PushDeepLinkRequest.tryParseChatId(
        '  private-chat-1  ',
      );
      final spacesBarRequest = PushDeepLinkRequest.tryParseSpacesBarMessageId(
        '  15  ',
      );

      expect(chatRequest?.chatId, 'private-chat-1');
      expect(spacesBarRequest?.spacesBarMessageId, '15');
    });

    test('rejects missing or non-string target ids', () {
      expect(PushDeepLinkRequest.tryParseChatId(null), isNull);
      expect(PushDeepLinkRequest.tryParseChatId(123), isNull);
      expect(PushDeepLinkRequest.tryParseSpacesBarMessageId(null), isNull);
      expect(PushDeepLinkRequest.tryParseSpacesBarMessageId(123), isNull);
      expect(PushDeepLinkRequest.fromRemoteData(const {}), isNull);
    });

    test('rejects empty target ids', () {
      expect(PushDeepLinkRequest.tryParseChatId(''), isNull);
      expect(PushDeepLinkRequest.tryParseChatId('   '), isNull);
      expect(PushDeepLinkRequest.tryParseSpacesBarMessageId(''), isNull);
      expect(PushDeepLinkRequest.tryParseSpacesBarMessageId('   '), isNull);
    });

    test('rejects target ids containing a slash', () {
      expect(
        PushDeepLinkRequest.tryParseChatId('chats/private-chat-1'),
        isNull,
      );
      expect(
        PushDeepLinkRequest.tryParseSpacesBarMessageId('spaces/spacesBar/42'),
        isNull,
      );
    });

    test('rejects an unknown explicit remote target type', () {
      expect(
        PushDeepLinkRequest.fromRemoteData({
          'deepLinkType': 'unknown',
          'chatId': 'chat-1',
        }),
        isNull,
      );
    });

    test('uses type-aware value equality', () {
      final first = PushDeepLinkRequest.tryParseChatId('1');
      final second = PushDeepLinkRequest.tryParseChatId('1');
      final differentChat = PushDeepLinkRequest.tryParseChatId('2');
      final spacesBar = PushDeepLinkRequest.tryParseSpacesBarMessageId('1');

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(differentChat));
      expect(first, isNot(spacesBar));
    });

    test('uses separate deduplication keys for different targets', () {
      final chat = PushDeepLinkRequest.tryParseChatId('1');
      final spacesBar = PushDeepLinkRequest.tryParseSpacesBarMessageId('1');

      expect(chat?.deduplicationKey, 'chat:1');
      expect(spacesBar?.deduplicationKey, 'spacesBar:1');
    });

    test('provides readable string representations', () {
      final chat = PushDeepLinkRequest.tryParseChatId('chat-1');
      final spacesBar = PushDeepLinkRequest.tryParseSpacesBarMessageId('7');

      expect(chat.toString(), 'PushDeepLinkRequest(chatId: chat-1)');
      expect(
        spacesBar.toString(),
        'PushDeepLinkRequest(spacesBarMessageId: 7)',
      );
    });
  });
}
