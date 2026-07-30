import '../../domain/models/message_preview.dart';
import 'message_content_mapper.dart';

final class MessagePreviewResolver {
  const MessagePreviewResolver._();

  static MessagePreview? resolve({
    required Map<String, dynamic> data,
    required String chatId,
    required String messageId,
    bool hiddenForCurrentUser = false,
  }) {
    if (hiddenForCurrentUser) {
      return null;
    }

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

    return MessagePreview(type: content.type, text: content.previewText);
  }
}
