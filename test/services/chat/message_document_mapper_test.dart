import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/message_content.dart';
import 'package:epistola/services/chat/image_message_metadata_mapper.dart';
import 'package:epistola/services/chat/message_document_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageDocumentMapper', () {
    test('builds a canonical text message document', () {
      final content = TextMessageContent.tryCreate('  Привет, Epistola!  ');

      expect(content, isNotNull);

      final createdAt = Object();

      final data = MessageDocumentMapper.toCreateMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        senderId: 'user-1',
        senderEmail: 'user@example.com',
        senderName: 'Пользователь',
        createdAt: createdAt,
        content: content!,
      );

      expect(data, {
        'messageType': 'text',
        'text': 'Привет, Epistola!',
        'senderId': 'user-1',
        'senderEmail': 'user@example.com',
        'senderName': 'Пользователь',
        'createdAt': same(createdAt),
      });
    });

    test('builds a canonical image message document', () {
      final content = ImageMessageContent.tryCreate(_imageMetadata());

      expect(content, isNotNull);

      final createdAt = Object();

      final data = MessageDocumentMapper.toCreateMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        senderId: 'user-1',
        senderEmail: 'user@example.com',
        senderName: 'Пользователь',
        createdAt: createdAt,
        content: content!,
      );

      expect(data, {
        'messageType': 'image',
        'text': '',
        'image': _imageMap(),
        'senderId': 'user-1',
        'senderEmail': 'user@example.com',
        'senderName': 'Пользователь',
        'createdAt': same(createdAt),
      });
    });

    test('keeps nullable sender email for current compatibility', () {
      final content = TextMessageContent.tryCreate('Сообщение');

      expect(content, isNotNull);

      final data = MessageDocumentMapper.toCreateMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        senderId: 'user-1',
        senderEmail: null,
        senderName: '',
        createdAt: Object(),
        content: content!,
      );

      expect(data['senderEmail'], isNull);
      expect(data['senderName'], '');
    });

    test('rejects an empty chat ID', () {
      final content = TextMessageContent.tryCreate('Сообщение');

      expect(content, isNotNull);

      expect(
        () => MessageDocumentMapper.toCreateMap(
          chatId: '   ',
          messageId: 'message-1',
          senderId: 'user-1',
          senderEmail: 'user@example.com',
          senderName: 'Пользователь',
          createdAt: Object(),
          content: content!,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an empty message ID', () {
      final content = TextMessageContent.tryCreate('Сообщение');

      expect(content, isNotNull);

      expect(
        () => MessageDocumentMapper.toCreateMap(
          chatId: 'chat-1',
          messageId: '',
          senderId: 'user-1',
          senderEmail: 'user@example.com',
          senderName: 'Пользователь',
          createdAt: Object(),
          content: content!,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an empty sender ID', () {
      final content = TextMessageContent.tryCreate('Сообщение');

      expect(content, isNotNull);

      expect(
        () => MessageDocumentMapper.toCreateMap(
          chatId: 'chat-1',
          messageId: 'message-1',
          senderId: '   ',
          senderEmail: 'user@example.com',
          senderName: 'Пользователь',
          createdAt: Object(),
          content: content!,
        ),
        throwsArgumentError,
      );
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
