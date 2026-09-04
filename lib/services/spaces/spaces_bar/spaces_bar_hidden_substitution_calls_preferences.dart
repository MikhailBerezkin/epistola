import 'package:shared_preferences/shared_preferences.dart';

final class SpacesBarHiddenSubstitutionCallsPreferences {
  static const String _hiddenCallIdsKeyPrefix =
      'spaces_bar.hidden_substitution_call_ids.v1';

  Future<Set<String>> loadHiddenCallIds({required String userId}) async {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');

    final preferences = await SharedPreferences.getInstance();

    final storedCallIds =
        preferences.getStringList(_keyForUser(normalizedUserId)) ??
        const <String>[];

    return storedCallIds
        .map((callId) => callId.trim())
        .where((callId) => callId.isNotEmpty)
        .toSet();
  }

  Future<void> hideCall({
    required String userId,
    required String callId,
  }) async {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');

    final normalizedCallId = _normalizeRequired(callId, argumentName: 'callId');

    final preferences = await SharedPreferences.getInstance();
    final key = _keyForUser(normalizedUserId);

    final hiddenCallIds = <String>{
      ...?preferences.getStringList(key)?.map((id) => id.trim()),
    }..removeWhere((id) => id.isEmpty);

    if (!hiddenCallIds.add(normalizedCallId)) {
      return;
    }

    await preferences.setStringList(key, hiddenCallIds.toList(growable: false));
  }

  String _keyForUser(String userId) {
    return '$_hiddenCallIdsKeyPrefix.$userId';
  }

  String _normalizeRequired(String value, {required String argumentName}) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, argumentName, 'must not be empty');
    }

    return normalized;
  }
}
