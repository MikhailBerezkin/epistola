import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/app_user.dart';

typedef SubstitutionUsersLoader =
    Future<List<AppUser>> Function(List<String> userIds);

final class SubstitutionUserCache {
  SubstitutionUserCache(this._loadUsers);

  factory SubstitutionUserCache.firebase({FirebaseFirestore? firestore}) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    return SubstitutionUserCache((userIds) async {
      final users = <AppUser>[];

      for (final userId in userIds) {
        final snapshot = await resolvedFirestore
            .collection('users')
            .doc(userId)
            .get();

        if (snapshot.exists) {
          users.add(AppUser.fromFirestore(snapshot));
        }
      }

      return users;
    });
  }

  final SubstitutionUsersLoader _loadUsers;

  final Map<String, AppUser> _usersById = <String, AppUser>{};

  final Set<String> _resolvedUserIds = <String>{};
  final Set<String> _loadingUserIds = <String>{};

  Map<String, AppUser> get usersById =>
      Map<String, AppUser>.unmodifiable(_usersById);

  AppUser? userById(String userId) {
    return _usersById[userId.trim()];
  }

  Future<bool> loadMissing(Iterable<String> userIds) async {
    final missingUserIds =
        userIds
            .map((userId) => userId.trim())
            .where(
              (userId) =>
                  userId.isNotEmpty &&
                  !_resolvedUserIds.contains(userId) &&
                  !_loadingUserIds.contains(userId),
            )
            .toSet()
            .toList()
          ..sort();

    if (missingUserIds.isEmpty) {
      return false;
    }

    _loadingUserIds.addAll(missingUserIds);

    try {
      final users = await _loadUsers(missingUserIds);

      for (final user in users) {
        final userId = user.uid.trim();

        if (userId.isNotEmpty) {
          _usersById[userId] = user;
        }
      }

      _resolvedUserIds.addAll(missingUserIds);

      return true;
    } finally {
      _loadingUserIds.removeAll(missingUserIds);
    }
  }
}
