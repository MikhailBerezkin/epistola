import 'package:epistola/domain/models/push_deep_link_request.dart';
import 'package:epistola/models/app_user.dart';
import 'package:epistola/services/push/push_deep_link_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushDeepLinkResolver', () {
    test('resolves a group chat for a current member', () async {
      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => 'current-user',
        loadChat: (chatId) async {
          expect(chatId, 'group-chat-1');

          return {
            'type': 'group',
            'name': 'Рабочая группа',
            'memberIds': ['current-user', 'member-2'],
          };
        },
        loadUser: (_) async => null,
      );

      final destination = await resolver.resolve(_request('group-chat-1'));

      expect(destination, isNotNull);
      expect(destination?.chatId, 'group-chat-1');
      expect(destination?.chatName, 'Рабочая группа');
      expect(destination?.chatType, PushDeepLinkChatType.group);
      expect(destination?.isPrivateChat, isFalse);
      expect(destination?.peerUser, isNull);
    });

    test('uses a fallback name for an unnamed group', () async {
      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => 'current-user',
        loadChat: (_) async => {
          'type': 'group',
          'name': '   ',
          'memberIds': ['current-user'],
        },
        loadUser: (_) async => null,
      );

      final destination = await resolver.resolve(_request('group-chat-1'));

      expect(destination?.chatName, 'Без названия');
    });

    test('resolves a private chat and loads the peer user', () async {
      const peerUser = AppUser(
        uid: 'peer-user',
        email: 'peer@example.com',
        name: 'Алекс Борн',
        phone: '',
        about: '',
      );

      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => 'current-user',
        loadChat: (_) async => {
          'type': 'private',
          'name': 'Legacy private chat name',
          'memberIds': ['current-user', 'peer-user'],
        },
        loadUser: (userId) async {
          expect(userId, 'peer-user');
          return peerUser;
        },
      );

      final destination = await resolver.resolve(_request('private-chat-1'));

      expect(destination, isNotNull);
      expect(destination?.chatId, 'private-chat-1');
      expect(destination?.chatName, 'Алекс Борн');
      expect(destination?.chatType, PushDeepLinkChatType.private);
      expect(destination?.isPrivateChat, isTrue);
      expect(destination?.peerUser, same(peerUser));
    });

    test('uses the peer email when the peer name is empty', () async {
      const peerUser = AppUser(
        uid: 'peer-user',
        email: 'peer@example.com',
        name: '',
        phone: '',
        about: '',
      );

      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => 'current-user',
        loadChat: (_) async => {
          'type': 'private',
          'memberIds': ['current-user', 'peer-user'],
        },
        loadUser: (_) async => peerUser,
      );

      final destination = await resolver.resolve(_request('private-chat-1'));

      expect(destination?.chatName, 'peer@example.com');
    });

    test('rejects a request when the user is not authenticated', () async {
      var didLoadChat = false;

      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => null,
        loadChat: (_) async {
          didLoadChat = true;
          return {};
        },
        loadUser: (_) async => null,
      );

      final destination = await resolver.resolve(_request('group-chat-1'));

      expect(destination, isNull);
      expect(didLoadChat, isFalse);
    });

    test('rejects a missing chat', () async {
      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => 'current-user',
        loadChat: (_) async => null,
        loadUser: (_) async => null,
      );

      final destination = await resolver.resolve(_request('missing-chat'));

      expect(destination, isNull);
    });

    test('rejects a chat where the current user is not a member', () async {
      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => 'current-user',
        loadChat: (_) async => {
          'type': 'group',
          'name': 'Чужая группа',
          'memberIds': ['member-1', 'member-2'],
        },
        loadUser: (_) async => null,
      );

      final destination = await resolver.resolve(_request('foreign-chat'));

      expect(destination, isNull);
    });

    test('rejects an unsupported chat type', () async {
      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => 'current-user',
        loadChat: (_) async => {
          'type': 'space',
          'memberIds': ['current-user'],
        },
        loadUser: (_) async => null,
      );

      final destination = await resolver.resolve(_request('unsupported-chat'));

      expect(destination, isNull);
    });

    test('rejects a private chat without another participant', () async {
      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => 'current-user',
        loadChat: (_) async => {
          'type': 'private',
          'memberIds': ['current-user'],
        },
        loadUser: (_) async => null,
      );

      final destination = await resolver.resolve(
        _request('invalid-private-chat'),
      );

      expect(destination, isNull);
    });
  });
}

PushDeepLinkRequest _request(String chatId) {
  return PushDeepLinkRequest.tryParseChatId(chatId)!;
}
