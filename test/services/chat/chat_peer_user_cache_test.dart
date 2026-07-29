import 'dart:async';

import 'package:epistola/models/app_user.dart';
import 'package:epistola/services/chat/chat_peer_user_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user1 = AppUser(
    uid: 'user-1',
    email: 'user1@example.com',
    name: 'User One',
    phone: '',
    about: '',
  );
  const user3 = AppUser(
    uid: 'user-3',
    email: 'user3@example.com',
    name: 'User Three',
    phone: '',
    about: '',
  );

  test('loads unique missing users and caches absent user ids', () async {
    final requests = <List<String>>[];
    final availableUsers = {'user-1': user1, 'user-3': user3};
    final cache = ChatPeerUserCache((userIds) async {
      requests.add(List<String>.from(userIds));
      return userIds
          .map((userId) => availableUsers[userId])
          .whereType<AppUser>()
          .toList();
    });

    expect(await cache.loadMissing(['user-2', 'user-1', 'user-1']), isTrue);
    expect(requests, [
      ['user-1', 'user-2'],
    ]);
    expect(cache.usersById, {'user-1': same(user1)});

    expect(await cache.loadMissing(['user-1', 'user-2']), isFalse);
    expect(requests, hasLength(1));

    expect(await cache.loadMissing(['user-2', 'user-3']), isTrue);
    expect(requests, [
      ['user-1', 'user-2'],
      ['user-3'],
    ]);
    expect(cache.usersById['user-3'], same(user3));
  });

  test(
    'does not request a user again while the first load is pending',
    () async {
      final completer = Completer<List<AppUser>>();
      var requestCount = 0;
      final cache = ChatPeerUserCache((userIds) {
        requestCount++;
        return completer.future;
      });

      final firstLoad = cache.loadMissing(['user-1']);
      final duplicateLoad = cache.loadMissing(['user-1']);

      expect(await duplicateLoad, isFalse);
      expect(requestCount, 1);

      completer.complete([user1]);

      expect(await firstLoad, isTrue);
      expect(cache.usersById['user-1'], same(user1));
    },
  );
}
