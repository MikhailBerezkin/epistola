import 'package:epistola/models/app_user.dart';
import 'package:epistola/services/chat/chat_peer_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatPeerResolver.otherUserId', () {
    test('returns the other member of a private chat', () {
      final userId = ChatPeerResolver.otherUserId(
        chatData: const {
          'type': 'private',
          'memberIds': ['current-user', 'other-user'],
        },
        currentUserId: 'current-user',
      );

      expect(userId, 'other-user');
    });

    test('does not depend on member order', () {
      final userId = ChatPeerResolver.otherUserId(
        chatData: const {
          'type': 'private',
          'memberIds': ['other-user', 'current-user'],
        },
        currentUserId: 'current-user',
      );

      expect(userId, 'other-user');
    });

    test('returns null for a group chat', () {
      final userId = ChatPeerResolver.otherUserId(
        chatData: const {
          'type': 'group',
          'memberIds': ['current-user', 'other-user'],
        },
        currentUserId: 'current-user',
      );

      expect(userId, isNull);
    });

    test('returns null for malformed member data', () {
      final userId = ChatPeerResolver.otherUserId(
        chatData: const {'type': 'private', 'memberIds': 'not-a-list'},
        currentUserId: 'current-user',
      );

      expect(userId, isNull);
    });
  });

  test('collects unique private chat peers', () {
    final userIds = ChatPeerResolver.collectOtherUserIds(
      chats: const [
        {
          'type': 'private',
          'memberIds': ['current-user', 'user-1'],
        },
        {
          'type': 'private',
          'memberIds': ['user-2', 'current-user'],
        },
        {
          'type': 'private',
          'memberIds': ['current-user', 'user-1'],
        },
        {
          'type': 'group',
          'memberIds': ['current-user', 'user-3'],
        },
      ],
      currentUserId: 'current-user',
    );

    expect(userIds, {'user-1', 'user-2'});
  });

  test('resolves a loaded AppUser without a Firebase request', () {
    const user = AppUser(
      uid: 'user-1',
      email: 'user1@example.com',
      name: 'Alex Born',
      phone: '',
      about: '',
    );

    final resolved = ChatPeerResolver.resolveOtherUser(
      chatData: const {
        'type': 'private',
        'memberIds': ['current-user', 'user-1'],
      },
      currentUserId: 'current-user',
      usersById: const {'user-1': user},
    );

    expect(resolved, same(user));
  });
}
