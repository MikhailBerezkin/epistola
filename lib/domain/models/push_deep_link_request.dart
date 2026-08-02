class PushDeepLinkRequest {
  const PushDeepLinkRequest._({required this.chatId});

  final String chatId;

  static PushDeepLinkRequest? fromRemoteData(Map<String, dynamic> data) {
    return tryParseChatId(data['chatId']);
  }

  static PushDeepLinkRequest? fromLocalPayload(String? payload) {
    return tryParseChatId(payload);
  }

  static PushDeepLinkRequest? tryParseChatId(Object? value) {
    if (value is! String) {
      return null;
    }

    final chatId = value.trim();

    if (chatId.isEmpty || chatId.contains('/')) {
      return null;
    }

    return PushDeepLinkRequest._(chatId: chatId);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PushDeepLinkRequest && other.chatId == chatId;
  }

  @override
  int get hashCode => chatId.hashCode;

  @override
  String toString() {
    return 'PushDeepLinkRequest(chatId: $chatId)';
  }
}
