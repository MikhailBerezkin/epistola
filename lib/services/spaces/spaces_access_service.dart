import '../../domain/models/spaces_access_role.dart';

typedef SpacesAccessRoleReader =
    Future<SpacesAccessRole?> Function({required String userId});

final class SpacesAccessService {
  SpacesAccessService({required SpacesAccessRoleReader roleReader})
    : _readRole = roleReader;

  final SpacesAccessRoleReader _readRole;

  final Map<String, SpacesAccessRole> _roleCache = <String, SpacesAccessRole>{};

  final Map<String, Future<SpacesAccessRole>> _pendingReads =
      <String, Future<SpacesAccessRole>>{};

  Future<SpacesAccessRole> getRole({required String userId}) {
    final normalizedUserId = _normalizeUserId(userId);

    final cachedRole = _roleCache[normalizedUserId];

    if (cachedRole != null) {
      return Future.value(cachedRole);
    }

    final pendingRead = _pendingReads[normalizedUserId];

    if (pendingRead != null) {
      return pendingRead;
    }

    final readFuture = _readAndCache(normalizedUserId);

    _pendingReads[normalizedUserId] = readFuture;

    return readFuture.whenComplete(() {
      _pendingReads.remove(normalizedUserId);
    });
  }

  void invalidateRole({required String userId}) {
    final normalizedUserId = _normalizeUserId(userId);

    _roleCache.remove(normalizedUserId);
  }

  void clearCache() {
    _roleCache.clear();
  }

  Future<SpacesAccessRole> _readAndCache(String userId) async {
    final role = await _readRole(userId: userId) ?? SpacesAccessRole.member;

    _roleCache[userId] = role;

    return role;
  }

  static String _normalizeUserId(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(
        value,
        'userId',
        'userId must be non-empty and must not contain slashes.',
      );
    }

    return normalized;
  }
}
