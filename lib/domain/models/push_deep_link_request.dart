import 'dart:convert';

enum PushDeepLinkTargetType { chat, spacesBar }

class PushDeepLinkRequest {
  const PushDeepLinkRequest._({
    required this.targetType,
    required this.targetId,
  });

  static const String _deepLinkTypeKey = 'deepLinkType';
  static const String _chatIdKey = 'chatId';
  static const String _spacesBarMessageIdKey = 'spacesBarMessageId';

  static const String _chatTypeValue = 'chat';
  static const String _spacesBarTypeValue = 'spacesBar';

  final PushDeepLinkTargetType targetType;
  final String targetId;

  bool get isChat => targetType == PushDeepLinkTargetType.chat;

  bool get isSpacesBar => targetType == PushDeepLinkTargetType.spacesBar;

  String? get chatId => isChat ? targetId : null;

  String? get spacesBarMessageId => isSpacesBar ? targetId : null;

  String get deduplicationKey {
    return switch (targetType) {
      PushDeepLinkTargetType.chat => 'chat:$targetId',
      PushDeepLinkTargetType.spacesBar => 'spacesBar:$targetId',
    };
  }

  static PushDeepLinkRequest? fromRemoteData(Map<String, dynamic> data) {
    final rawType = data[_deepLinkTypeKey];

    // Backward compatibility with all existing chat push notifications.
    if (rawType == null) {
      return tryParseChatId(data[_chatIdKey]);
    }

    if (rawType is! String) {
      return null;
    }

    switch (rawType.trim()) {
      case _chatTypeValue:
        return tryParseChatId(data[_chatIdKey]);

      case _spacesBarTypeValue:
        return tryParseSpacesBarMessageId(data[_spacesBarMessageIdKey]);

      default:
        return null;
    }
  }

  static PushDeepLinkRequest? fromLocalPayload(String? payload) {
    if (payload == null) {
      return null;
    }

    final normalizedPayload = payload.trim();

    if (normalizedPayload.isEmpty) {
      return null;
    }

    // New typed payload format.
    if (normalizedPayload.startsWith('{')) {
      try {
        final decoded = jsonDecode(normalizedPayload);

        if (decoded is Map) {
          final data = <String, dynamic>{};

          for (final entry in decoded.entries) {
            if (entry.key is! String) {
              return null;
            }

            data[entry.key as String] = entry.value;
          }

          return fromRemoteData(data);
        }

        return null;
      } on FormatException {
        // A legacy chat id may theoretically begin with "{".
        // Fall through to the legacy parser.
      }
    }

    // Backward compatibility with existing local notifications,
    // where payload was simply the raw chatId.
    return tryParseChatId(normalizedPayload);
  }

  static PushDeepLinkRequest? tryParseChatId(Object? value) {
    return _tryParseTarget(
      targetType: PushDeepLinkTargetType.chat,
      value: value,
    );
  }

  static PushDeepLinkRequest? tryParseSpacesBarMessageId(Object? value) {
    return _tryParseTarget(
      targetType: PushDeepLinkTargetType.spacesBar,
      value: value,
    );
  }

  String toLocalPayload() {
    final data = switch (targetType) {
      PushDeepLinkTargetType.chat => <String, dynamic>{
        _deepLinkTypeKey: _chatTypeValue,
        _chatIdKey: targetId,
      },
      PushDeepLinkTargetType.spacesBar => <String, dynamic>{
        _deepLinkTypeKey: _spacesBarTypeValue,
        _spacesBarMessageIdKey: targetId,
      },
    };

    return jsonEncode(data);
  }

  static PushDeepLinkRequest? _tryParseTarget({
    required PushDeepLinkTargetType targetType,
    required Object? value,
  }) {
    if (value is! String) {
      return null;
    }

    final targetId = value.trim();

    if (targetId.isEmpty || targetId.contains('/')) {
      return null;
    }

    return PushDeepLinkRequest._(targetType: targetType, targetId: targetId);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PushDeepLinkRequest &&
            other.targetType == targetType &&
            other.targetId == targetId;
  }

  @override
  int get hashCode => Object.hash(targetType, targetId);

  @override
  String toString() {
    return switch (targetType) {
      PushDeepLinkTargetType.chat => 'PushDeepLinkRequest(chatId: $targetId)',
      PushDeepLinkTargetType.spacesBar =>
        'PushDeepLinkRequest(spacesBarMessageId: $targetId)',
    };
  }
}
