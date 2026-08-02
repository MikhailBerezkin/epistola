import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/message_type.dart';
import 'package:epistola/services/chat/message_push_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagePushResolver', () {
    test('resolves a legacy text message', () {
      final representation = MessagePushResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'text': '  Старое сообщение  '},
      );

      expect(representation, isNotNull);
      expect(representation!.type, MessageType.text);
      expect(representation.text, 'Старое сообщение');
    });

    test('resolves an explicit text message', () {
      final representation = MessagePushResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': 'text', 'text': 'Новое сообщение'},
      );

      expect(representation, isNotNull);
      expect(representation!.type, MessageType.text);
      expect(representation.text, 'Новое сообщение');
    });

    test('resolves an image message as Photograph', () {
      final representation = MessagePushResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': 'image', 'text': '', 'image': _imageMap()},
      );

      expect(representation, isNotNull);
      expect(representation!.type, MessageType.image);
      expect(representation.text, 'Фотография');
    });

    test('ignores a message deleted for everyone', () {
      final representation = MessagePushResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {
          'messageType': 'text',
          'text': 'Удалённое сообщение',
          'deletedForEveryone': true,
        },
      );

      expect(representation, isNull);
    });

    test('rejects an invalid deletion flag', () {
      final representation = MessagePushResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {
          'messageType': 'text',
          'text': 'Сообщение',
          'deletedForEveryone': 'true',
        },
      );

      expect(representation, isNull);
    });

    test('rejects malformed image metadata', () {
      final representation = MessagePushResolver.resolve(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {
          'messageType': 'image',
          'text': '',
          'image': {'provider': 'firebase'},
        },
      );

      expect(representation, isNull);
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
