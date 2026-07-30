import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/message_type.dart';
import 'package:epistola/services/chat/message_preview_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagePreviewResolver', () {
    test('resolves a legacy text message', () {
      final preview = MessagePreviewResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'text': '  Старое сообщение  '},
      );

      expect(preview, isNotNull);
      expect(preview!.type, MessageType.text);
      expect(preview.text, 'Старое сообщение');
    });

    test('resolves an explicit text message', () {
      final preview = MessagePreviewResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': 'text', 'text': 'Новое сообщение'},
      );

      expect(preview, isNotNull);
      expect(preview!.type, MessageType.text);
      expect(preview.text, 'Новое сообщение');
    });

    test('resolves image content as Photograph', () {
      final preview = MessagePreviewResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': 'image', 'text': '', 'image': _imageMap()},
      );

      expect(preview, isNotNull);
      expect(preview!.type, MessageType.image);
      expect(preview.text, 'Фотография');
    });

    test('ignores a message deleted for everyone', () {
      final preview = MessagePreviewResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {
          'messageType': 'image',
          'text': '',
          'image': _imageMap(),
          'deletedForEveryone': true,
        },
      );

      expect(preview, isNull);
    });

    test('ignores a message hidden for the current user', () {
      final preview = MessagePreviewResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        hiddenForCurrentUser: true,
        data: {'messageType': 'text', 'text': 'Скрытое сообщение'},
      );

      expect(preview, isNull);
    });

    test('rejects an invalid deletion flag', () {
      final preview = MessagePreviewResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {
          'messageType': 'text',
          'text': 'Сообщение',
          'deletedForEveryone': 'true',
        },
      );

      expect(preview, isNull);
    });

    test('rejects malformed message content', () {
      final preview = MessagePreviewResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {
          'messageType': 'image',
          'text': '',
          'image': {'provider': 'firebase'},
        },
      );

      expect(preview, isNull);
    });
  });
}

Map<String, dynamic> _imageMap() {
  return {
    'provider': 'firebase',
    'thumbStoragePath': 'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
    'fullStoragePath': 'chat_media/chat-1/messages/message-1/v3/full.jpg',
    'thumbSizeBytes': 24000,
    'fullSizeBytes': 280000,
    'thumbWidth': 320,
    'thumbHeight': 180,
    'fullWidth': 1600,
    'fullHeight': 900,
    'mimeType': ImageMessageMetadata.supportedMimeType,
    'version': 3,
  };
}
