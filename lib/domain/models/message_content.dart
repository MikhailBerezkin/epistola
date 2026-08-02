import '../value_objects/message_text.dart';
import 'image_message_metadata.dart';
import 'message_type.dart';

sealed class MessageContent {
  const MessageContent();

  MessageType get type;

  String get previewText;

  String get pushText;
}

final class TextMessageContent extends MessageContent {
  const TextMessageContent._(this.text);

  final String text;

  static TextMessageContent? tryCreate(String rawText) {
    final parsedText = MessageText.tryParse(rawText);

    if (parsedText == null) {
      return null;
    }

    return TextMessageContent._(parsedText.value);
  }

  @override
  MessageType get type => MessageType.text;

  @override
  String get previewText => text;

  @override
  String get pushText => text;
}

final class ImageMessageContent extends MessageContent {
  const ImageMessageContent._(this.metadata);

  static const String representationText = 'Фотография';

  final ImageMessageMetadata metadata;

  static ImageMessageContent? tryCreate(ImageMessageMetadata metadata) {
    if (!metadata.hasPersistableMetadata) {
      return null;
    }

    return ImageMessageContent._(metadata);
  }

  @override
  MessageType get type => MessageType.image;

  @override
  String get previewText => representationText;

  @override
  String get pushText => representationText;
}
