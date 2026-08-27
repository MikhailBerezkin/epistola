import 'package:epistola/models/app_user.dart';
import 'package:epistola/services/spaces/substitution/substitution_user_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads each missing user only once', () async {
    final loadRequests = <List<String>>[];

    final cache = SubstitutionUserCache((userIds) async {
      loadRequests.add(List<String>.from(userIds));

      return userIds
          .map(
            (userId) => AppUser(
              uid: userId,
              email: '$userId@example.com',
              name: 'Name $userId',
              phone: '',
              about: '',
            ),
          )
          .toList();
    });

    final firstChanged = await cache.loadMissing([
      'user-2',
      'user-1',
      'user-2',
    ]);

    final secondChanged = await cache.loadMissing(['user-1', 'user-2']);

    expect(firstChanged, isTrue);
    expect(secondChanged, isFalse);

    expect(loadRequests, hasLength(1));
    expect(loadRequests.single, ['user-1', 'user-2']);

    expect(cache.userById('user-1')?.uid, 'user-1');
    expect(cache.userById('user-2')?.uid, 'user-2');
  });

  test('loads only newly missing users on later calls', () async {
    final loadRequests = <List<String>>[];

    final cache = SubstitutionUserCache((userIds) async {
      loadRequests.add(List<String>.from(userIds));

      return userIds
          .map(
            (userId) => AppUser(
              uid: userId,
              email: '$userId@example.com',
              name: 'Name $userId',
              phone: '',
              about: '',
            ),
          )
          .toList();
    });

    await cache.loadMissing(['user-1', 'user-2']);
    await cache.loadMissing(['user-2', 'user-3']);

    expect(loadRequests, hasLength(2));
    expect(loadRequests[0], ['user-1', 'user-2']);
    expect(loadRequests[1], ['user-3']);
  });

  test('trims ids and ignores empty values', () async {
    final loadRequests = <List<String>>[];

    final cache = SubstitutionUserCache((userIds) async {
      loadRequests.add(List<String>.from(userIds));

      return userIds
          .map(
            (userId) => AppUser(
              uid: userId,
              email: '$userId@example.com',
              name: 'Name $userId',
              phone: '',
              about: '',
            ),
          )
          .toList();
    });

    await cache.loadMissing([' user-1 ', '', '   ', 'user-2']);

    expect(loadRequests.single, ['user-1', 'user-2']);
  });

  test('stores loaded users by normalized uid', () async {
    final cache = SubstitutionUserCache((userIds) async {
      return const [
        AppUser(
          uid: ' user-1 ',
          email: 'user-1@example.com',
          name: 'Иван Иванов',
          workDisplayName: 'Иванов Иван',
          phone: '',
          about: '',
        ),
      ];
    });

    await cache.loadMissing(['user-1']);

    final user = cache.userById('user-1');

    expect(user, isNotNull);
    expect(user?.effectiveWorkDisplayName, 'Иванов Иван');
  });

  test('falls back from workDisplayName to name', () async {
    final cache = SubstitutionUserCache((userIds) async {
      return const [
        AppUser(
          uid: 'user-1',
          email: 'user-1@example.com',
          name: 'Иван Иванов',
          workDisplayName: '',
          phone: '',
          about: '',
        ),
      ];
    });

    await cache.loadMissing(['user-1']);

    expect(cache.userById('user-1')?.effectiveWorkDisplayName, 'Иван Иванов');
  });

  test('unmodifiable usersById cannot be changed externally', () async {
    final cache = SubstitutionUserCache((userIds) async {
      return const [
        AppUser(
          uid: 'user-1',
          email: 'user-1@example.com',
          name: 'Иван Иванов',
          phone: '',
          about: '',
        ),
      ];
    });

    await cache.loadMissing(['user-1']);

    expect(
      () => cache.usersById['user-2'] = const AppUser(
        uid: 'user-2',
        email: 'user-2@example.com',
        name: 'Пётр Петров',
        phone: '',
        about: '',
      ),
      throwsUnsupportedError,
    );
  });
}
