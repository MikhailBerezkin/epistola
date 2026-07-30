import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/message_content.dart';
import 'package:epistola/domain/models/message_type.dart';
import 'package:epistola/services/chat/image_message_metadata_mapper.dart';
import 'package:epistola/services/chat/message_content_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageContentMapper', () {
    test('reads a legacy text message without messageType', () {
      final content = MessageContentMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'text': '  Привет!  '},
      );

      expect(content, isA<TextMessageContent>());

      final textContent = content! as TextMessageContent;

      expect(textContent.type, MessageType.text);
      expect(textContent.text, 'Привет!');
    });

    test('reads an explicit text message', () {
      final content = MessageContentMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': 'text', 'text': 'Текстовое сообщение'},
      );

      expect(content, isA<TextMessageContent>());
      expect((content! as TextMessageContent).text, 'Текстовое сообщение');
    });

    test('rejects an unknown message type', () {
      final content = MessageContentMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': 'video', 'text': ''},
      );

      expect(content, isNull);
    });

    test('rejects an explicit null message type', () {
      final content = MessageContentMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': null, 'text': 'Привет'},
      );

      expect(content, isNull);
    });

    test('rejects text content containing image metadata', () {
      final content = MessageContentMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': 'text', 'text': 'Привет', 'image': _imageMap()},
      );

      expect(content, isNull);
    });

    test('reads valid image content', () {
      final content = MessageContentMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': 'image', 'text': '', 'image': _imageMap()},
      );

      expect(content, isA<ImageMessageContent>());

      final imageContent = content! as ImageMessageContent;

      expect(imageContent.type, MessageType.image);
      expect(imageContent.previewText, 'Фотография');
      expect(imageContent.metadata.version, 3);
    });

    test('rejects image content with non-empty text', () {
      final content = MessageContentMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': 'image', 'text': 'Подпись', 'image': _imageMap()},
      );

      expect(content, isNull);
    });

    test('rejects image content without complete metadata', () {
      final imageData = _imageMap()..remove('fullStoragePath');

      final content = MessageContentMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: {'messageType': 'image', 'text': '', 'image': imageData},
      );

      expect(content, isNull);
    });

    test('writes text content in canonical form', () {
      final content = TextMessageContent.tryCreate('  Новое сообщение  ');

      expect(content, isNotNull);

      final data = MessageContentMapper.toMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        content: content!,
      );

      expect(data, {'messageType': 'text', 'text': 'Новое сообщение'});
    });

    test('writes image content in canonical form', () {
      final content = ImageMessageContent.tryCreate(_imageMetadata());

      expect(content, isNotNull);

      final data = MessageContentMapper.toMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        content: content!,
      );

      expect(data, {'messageType': 'image', 'text': '', 'image': _imageMap()});
    });
  });
}

ImageMessageMetadata _imageMetadata() {
  final metadata = ImageMessageMetadataMapper.fromMap(
    chatId: 'chat-1',
    messageId: 'message-1',
    data: _imageMap(),
  );

  if (metadata == null) {
    throw StateError('Test image metadata must be valid.');
  }

  return metadata;
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
