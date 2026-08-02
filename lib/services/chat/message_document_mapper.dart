import '../../domain/models/message_content.dart';
import 'message_content_mapper.dart';

final class MessageDocumentMapper {
  static Map<String, dynamic> toCreateMap({
    required String chatId,
    required String messageId,
    required String senderId,
    required String? senderEmail,
    required String senderName,
    required Object createdAt,
    required MessageContent content,
  }) {
    final normalizedChatId = chatId.trim();
    final normalizedMessageId = messageId.trim();
    final normalizedSenderId = senderId.trim();

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

    if (normalizedSenderId.isEmpty) {
      throw ArgumentError.value(
        senderId,
        'senderId',
        'Sender ID must not be empty.',
      );
    }

    return {
      ...MessageContentMapper.toMap(
        content: content,
        chatId: normalizedChatId,
        messageId: normalizedMessageId,
      ),
      'senderId': normalizedSenderId,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'createdAt': createdAt,
    };
  }
}
