final class PrivateReadCursor {
  PrivateReadCursor._({
    required this.messageId,
    required this.messageCreatedAt,
  });

  final String messageId;
  final DateTime messageCreatedAt;

  static PrivateReadCursor? tryCreate({
    required String messageId,
    required DateTime? messageCreatedAt,
  }) {
    final normalizedMessageId = messageId.trim();

    if (normalizedMessageId.isEmpty ||
        normalizedMessageId.contains('/') ||
        messageCreatedAt == null) {
      return null;
    }

    return PrivateReadCursor._(
      messageId: normalizedMessageId,
      messageCreatedAt: messageCreatedAt.toUtc(),
    );
  }

  bool covers({required String messageId, required DateTime messageCreatedAt}) {
    final normalizedMessageId = messageId.trim();

    if (normalizedMessageId.isEmpty || normalizedMessageId.contains('/')) {
      return false;
    }

    final candidateCreatedAt = messageCreatedAt.toUtc();

    if (candidateCreatedAt.isBefore(this.messageCreatedAt)) {
      return true;
    }

    if (candidateCreatedAt.isAfter(this.messageCreatedAt)) {
      return false;
    }

    return normalizedMessageId == this.messageId;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PrivateReadCursor &&
            other.messageId == messageId &&
            other.messageCreatedAt == messageCreatedAt;
  }

  @override
  int get hashCode => Object.hash(messageId, messageCreatedAt);

  @override
  String toString() {
    return 'PrivateReadCursor('
        'messageId: $messageId, '
        'messageCreatedAt: $messageCreatedAt'
        ')';
  }
}
