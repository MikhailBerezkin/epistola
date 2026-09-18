import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/app_user.dart';

typedef SubstitutionUsersLoader =
    Future<List<AppUser>> Function(List<String> userIds);

final class SubstitutionUserCache {
  SubstitutionUserCache(this._loadUsers);

  factory SubstitutionUserCache.firebase({FirebaseFirestore? firestore}) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    return SubstitutionUserCache((userIds) async {
      final uniqueUserIds = userIds
          .map((userId) => userId.trim())
          .where((userId) => userId.isNotEmpty)
          .toSet()
          .toList();

      if (uniqueUserIds.isEmpty) {
        return [];
      }

      final snapshots = await Future.wait(
        uniqueUserIds.map(
          (userId) => resolvedFirestore.collection('users').doc(userId).get(),
        ),
      );

      return snapshots
          .where((snapshot) => snapshot.exists)
          .map(AppUser.fromFirestore)
          .toList();
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

  Future<bool> refresh(String userId) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty ||
        _loadingUserIds.contains(normalizedUserId)) {
      return false;
    }

    _loadingUserIds.add(normalizedUserId);

    try {
      final users = await _loadUsers(<String>[normalizedUserId]);

      AppUser? refreshedUser;

      for (final user in users) {
        if (user.uid.trim() == normalizedUserId) {
          refreshedUser = user;
          break;
        }
      }

      if (refreshedUser == null) {
        _usersById.remove(normalizedUserId);
      } else {
        _usersById[normalizedUserId] = refreshedUser;
      }

      _resolvedUserIds.add(normalizedUserId);

      return true;
    } finally {
      _loadingUserIds.remove(normalizedUserId);
    }
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
