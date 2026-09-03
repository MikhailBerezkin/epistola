import 'package:shared_preferences/shared_preferences.dart';

class SpacesBarHiddenMessagesPreferences {
  static const String _hiddenMessageIdsKeyPrefix =
      'spaces_bar.hidden_message_ids.v1';

  Future<Set<String>> loadHiddenMessageIds({required String userId}) async {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');

    final preferences = await SharedPreferences.getInstance();
    final storedMessageIds =
        preferences.getStringList(_keyForUser(normalizedUserId)) ??
        const <String>[];

    return storedMessageIds
        .map((messageId) => messageId.trim())
        .where((messageId) => messageId.isNotEmpty)
        .toSet();
  }

  Future<void> hideMessage({
    required String userId,
    required String messageId,
  }) async {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');
    final normalizedMessageId = _normalizeRequired(
      messageId,
      argumentName: 'messageId',
    );

    final preferences = await SharedPreferences.getInstance();
    final key = _keyForUser(normalizedUserId);

    final hiddenMessageIds = <String>{
      ...?preferences.getStringList(key)?.map((id) => id.trim()),
    }..removeWhere((id) => id.isEmpty);

    if (!hiddenMessageIds.add(normalizedMessageId)) {
      return;
    }

    await preferences.setStringList(
      key,
      hiddenMessageIds.toList(growable: false),
    );
  }

  String _keyForUser(String userId) {
    return '$_hiddenMessageIdsKeyPrefix.$userId';
  }

  String _normalizeRequired(String value, {required String argumentName}) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, argumentName, 'must not be empty');
    }

    return normalized;
  }
}
