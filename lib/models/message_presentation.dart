enum MessageVisibilityState {
  visible,
  hiddenForCurrentUser,
  deletedForEveryone,
}

class MessagePresentation {
  const MessagePresentation({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
    required this.visibility,
  });

  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime? createdAt;
  final MessageVisibilityState visibility;

  bool get isVisible => visibility == MessageVisibilityState.visible;
}
