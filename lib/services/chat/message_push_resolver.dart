import '../../domain/models/message_push_representation.dart';
import 'message_content_mapper.dart';

final class MessagePushResolver {
  const MessagePushResolver._();

  static MessagePushRepresentation? resolve({
    required Map<String, dynamic> data,
    required String chatId,
    required String messageId,
  }) {
    final deletedForEveryone = data['deletedForEveryone'];

    if (deletedForEveryone != null && deletedForEveryone is! bool) {
      return null;
    }

    if (deletedForEveryone == true) {
      return null;
    }

    final content = MessageContentMapper.fromMap(
      data: data,
      chatId: chatId,
      messageId: messageId,
    );

    if (content == null) {
      return null;
    }

    return MessagePushRepresentation(
      type: content.type,
      text: content.pushText,
    );
  }
}
