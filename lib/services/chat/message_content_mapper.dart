import '../../domain/models/message_content.dart';
import '../../domain/models/message_type.dart';
import 'image_message_metadata_mapper.dart';

final class MessageContentMapper {
  static MessageContent? fromMap({
    required Map<String, dynamic> data,
    required String chatId,
    required String messageId,
  }) {
    final normalizedChatId = chatId.trim();
    final normalizedMessageId = messageId.trim();

    if (normalizedChatId.isEmpty || normalizedMessageId.isEmpty) {
      return null;
    }

    final hasStoredType = data.containsKey('messageType');
    final storedType = data['messageType'];

    // Старые сообщения вообще не содержат messageType.
    // Явный null не считается корректным legacy-значением.
    if (hasStoredType && storedType == null) {
      return null;
    }

    final type = MessageType.tryParseStorageValue(
      hasStoredType ? storedType : null,
    );

    if (type == null) {
      return null;
    }

    return switch (type) {
      MessageType.text => _readTextContent(data),
      MessageType.image => _readImageContent(
        data: data,
        chatId: normalizedChatId,
        messageId: normalizedMessageId,
      ),
    };
  }

  static Map<String, dynamic> toMap({
    required MessageContent content,
    required String chatId,
    required String messageId,
  }) {
    final normalizedChatId = chatId.trim();
    final normalizedMessageId = messageId.trim();

    if (normalizedChatId.isEmpty) {
      throw ArgumentError.value(chatId, 'chatId', 'Chat ID must not be empty.');
    }

    if (normalizedMessageId.isEmpty) {
      throw ArgumentError.value(
        messageId,
        'messageId',
        'Message ID must not be empty.',
      );
    }

    if (content is TextMessageContent) {
      return {
        'messageType': MessageType.text.storageValue,
        'text': content.text,
      };
    }

    if (content is ImageMessageContent) {
      return {
        'messageType': MessageType.image.storageValue,
        'text': '',
        'image': ImageMessageMetadataMapper.toMap(
          chatId: normalizedChatId,
          messageId: normalizedMessageId,
          metadata: content.metadata,
        ),
      };
    }

    throw UnsupportedError(
      'Unsupported message content: ${content.runtimeType}.',
    );
  }

  static TextMessageContent? _readTextContent(Map<String, dynamic> data) {
    if (data.containsKey('image')) {
      return null;
    }

    final text = data['text'];

    if (text is! String) {
      return null;
    }

    return TextMessageContent.tryCreate(text);
  }

  static ImageMessageContent? _readImageContent({
    required Map<String, dynamic> data,
    required String chatId,
    required String messageId,
  }) {
    final text = data['text'];

    if (text is! String || text.isNotEmpty) {
      return null;
    }

    final imageData = _readStringKeyedMap(data['image']);

    if (imageData == null) {
      return null;
    }

    final metadata = ImageMessageMetadataMapper.fromMap(
      data: imageData,
      chatId: chatId,
      messageId: messageId,
    );

    if (metadata == null) {
      return null;
    }

    return ImageMessageContent.tryCreate(metadata);
  }

  static Map<String, dynamic>? _readStringKeyedMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    final result = <String, dynamic>{};

    for (final entry in value.entries) {
      final key = entry.key;

      if (key is! String) {
        return null;
      }

      result[key] = entry.value;
    }

    return result;
  }
}
