final activeChatTracker = ActiveChatTracker();

final class ActiveChatRegistration {
  ActiveChatRegistration._();
}

final class ActiveChatTracker {
  final List<_ActiveChatEntry> _entries = <_ActiveChatEntry>[];

  ActiveChatRegistration enter(String chatId) {
    final normalizedChatId = chatId.trim();

    if (normalizedChatId.isEmpty || normalizedChatId.contains('/')) {
      throw ArgumentError.value(
        chatId,
        'chatId',
        'Chat ID must be a non-empty string without slashes.',
      );
    }

    final registration = ActiveChatRegistration._();

    _entries.add(
      _ActiveChatEntry(registration: registration, chatId: normalizedChatId),
    );

    return registration;
  }

  void leave(ActiveChatRegistration registration) {
    _entries.removeWhere(
      (entry) => identical(entry.registration, registration),
    );
  }

  String? get currentChatId {
    if (_entries.isEmpty) {
      return null;
    }

    return _entries.last.chatId;
  }

  bool isCurrent(String chatId) {
    final normalizedChatId = chatId.trim();

    if (normalizedChatId.isEmpty) {
      return false;
    }

    return currentChatId == normalizedChatId;
  }
}

final class _ActiveChatEntry {
  const _ActiveChatEntry({required this.registration, required this.chatId});

  final ActiveChatRegistration registration;
  final String chatId;
}
