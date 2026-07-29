import '../../models/app_user.dart';

typedef ChatPeerUsersLoader =
    Future<List<AppUser>> Function(List<String> userIds);

class ChatPeerUserCache {
  final ChatPeerUsersLoader _loadUsers;
  final Map<String, AppUser> _usersById = {};
  final Set<String> _resolvedUserIds = {};
  final Set<String> _loadingUserIds = {};

  ChatPeerUserCache(this._loadUsers);

  Map<String, AppUser> get usersById => _usersById;

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
