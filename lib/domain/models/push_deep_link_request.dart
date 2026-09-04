import 'dart:convert';

enum PushDeepLinkTargetType { chat, spacesBar }

class PushDeepLinkRequest {
  const PushDeepLinkRequest._({
    required this.targetType,
    required this.targetId,
  });

  static const String _deepLinkTypeKey = 'deepLinkType';
  static const String _chatIdKey = 'chatId';

  // Legacy general SpacesBar push field.
  static const String _spacesBarMessageIdKey = 'spacesBarMessageId';

  // New unified SpacesBar target field.
  static const String _spacesBarPresentationIdKey = 'spacesBarPresentationId';

  static const String _chatTypeValue = 'chat';
  static const String _spacesBarTypeValue = 'spacesBar';

  static const String _generalPresentationPrefix = 'general:';
  static const String _substitutionPresentationPrefix = 'substitution:';

  final PushDeepLinkTargetType targetType;
  final String targetId;

  bool get isChat => targetType == PushDeepLinkTargetType.chat;

  bool get isSpacesBar => targetType == PushDeepLinkTargetType.spacesBar;

  String? get chatId => isChat ? targetId : null;

  String? get spacesBarPresentationId {
    return isSpacesBar ? targetId : null;
  }

  /// Backward-compatible general SpacesBar message ID.
  ///
  /// For a substitution target this intentionally returns null.
  String? get spacesBarMessageId {
    if (!isSpacesBar || !targetId.startsWith(_generalPresentationPrefix)) {
      return null;
    }

    return targetId.substring(_generalPresentationPrefix.length);
  }

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
        final presentationRequest = tryParseSpacesBarPresentationId(
          data[_spacesBarPresentationIdKey],
        );

        if (presentationRequest != null) {
          return presentationRequest;
        }

        // Backward compatibility with already deployed general
        // SpacesBar notifications.
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

    // Typed payload format.
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

    // Backward compatibility with old local notifications,
    // where payload was simply the raw chatId.
    return tryParseChatId(normalizedPayload);
  }

  static PushDeepLinkRequest? tryParseChatId(Object? value) {
    final targetId = _normalizeTargetId(value);

    if (targetId == null) {
      return null;
    }

    return PushDeepLinkRequest._(
      targetType: PushDeepLinkTargetType.chat,
      targetId: targetId,
    );
  }

  /// Backward-compatible parser for general SpacesBar message IDs.
  ///
  /// Internally they are normalized into:
  ///
  /// `general:<messageId>`
  static PushDeepLinkRequest? tryParseSpacesBarMessageId(Object? value) {
    final messageId = _normalizeTargetId(value);

    if (messageId == null) {
      return null;
    }

    return PushDeepLinkRequest._(
      targetType: PushDeepLinkTargetType.spacesBar,
      targetId: '$_generalPresentationPrefix$messageId',
    );
  }

  /// Parses a unified SpacesBar presentation ID:
  ///
  /// `general:<messageId>`
  /// `substitution:<callId>`
  static PushDeepLinkRequest? tryParseSpacesBarPresentationId(Object? value) {
    final presentationId = _normalizeTargetId(value);

    if (presentationId == null) {
      return null;
    }

    final isGeneral = presentationId.startsWith(_generalPresentationPrefix);
    final isSubstitution = presentationId.startsWith(
      _substitutionPresentationPrefix,
    );

    if (!isGeneral && !isSubstitution) {
      return null;
    }

    final separatorIndex = presentationId.indexOf(':');

    if (separatorIndex < 0 || separatorIndex == presentationId.length - 1) {
      return null;
    }

    return PushDeepLinkRequest._(
      targetType: PushDeepLinkTargetType.spacesBar,
      targetId: presentationId,
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
        _spacesBarPresentationIdKey: targetId,
      },
    };

    return jsonEncode(data);
  }

  static String? _normalizeTargetId(Object? value) {
    if (value is! String) {
      return null;
    }

    final targetId = value.trim();

    if (targetId.isEmpty || targetId.contains('/')) {
      return null;
    }

    return targetId;
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
        'PushDeepLinkRequest(spacesBarPresentationId: $targetId)',
    };
  }
}
