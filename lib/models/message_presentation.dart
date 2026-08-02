import '../domain/models/image_message_metadata.dart';

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
    this.isImageMessage = false,
    this.imageMetadata,
  });

  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime? createdAt;
  final MessageVisibilityState visibility;

  final bool isImageMessage;
  final ImageMessageMetadata? imageMetadata;

  bool get isVisible => visibility == MessageVisibilityState.visible;

  bool get hasRenderableImage {
    return isImageMessage && imageMetadata != null;
  }
}
