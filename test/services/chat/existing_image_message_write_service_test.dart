import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/services/chat/existing_image_message_write_service.dart';
import 'package:epistola/services/chat/image_message_metadata_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExistingImageMessageWriteService', () {
    test('creates and validates a message ID', () {
      String? receivedChatId;

      final service = ExistingImageMessageWriteService(
        createMessageId: (chatId) {
          receivedChatId = chatId;

          return 'message-1';
        },
        loadSender: () async {
          return const ImageMessageSenderIdentity(
            userId: 'user-1',
            email: 'user@example.com',
            name: 'Пользователь',
          );
        },
        createTimestamp: Object.new,
        commit:
            ({
              required String chatId,
              required String messageId,
              required Map<String, dynamic> messageData,
              required String previewText,
              required Object lastMessageAt,
            }) async {},
      );

      final messageId = service.createMessageId(chatId: 'chat-1');

      expect(messageId, 'message-1');
      expect(receivedChatId, 'chat-1');
    });

    test('writes a canonical image message and chat preview', () async {
      final createdAt = Object();

      String? committedChatId;
      String? committedMessageId;
      Map<String, dynamic>? committedMessageData;
      String? committedPreviewText;
      Object? committedLastMessageAt;

      final service = ExistingImageMessageWriteService(
        createMessageId: (_) => 'message-1',
        loadSender: () async {
          return const ImageMessageSenderIdentity(
            userId: 'user-1',
            email: 'user@example.com',
            name: 'Пользователь',
          );
        },
        createTimestamp: () => createdAt,
        commit:
            ({
              required String chatId,
              required String messageId,
              required Map<String, dynamic> messageData,
              required String previewText,
              required Object lastMessageAt,
            }) async {
              committedChatId = chatId;
              committedMessageId = messageId;
              committedMessageData = messageData;
              committedPreviewText = previewText;
              committedLastMessageAt = lastMessageAt;
            },
      );

      await service.writeImageMessage(
        chatId: 'chat-1',
        messageId: 'message-1',
        metadata: _imageMetadata(chatId: 'chat-1', messageId: 'message-1'),
      );

      expect(committedChatId, 'chat-1');
      expect(committedMessageId, 'message-1');
      expect(committedPreviewText, 'Фотография');
      expect(committedLastMessageAt, same(createdAt));

      expect(committedMessageData, {
        'messageType': 'image',
        'text': '',
        'image': _imageMap(chatId: 'chat-1', messageId: 'message-1'),
        'senderId': 'user-1',
        'senderEmail': 'user@example.com',
        'senderName': 'Пользователь',
        'createdAt': same(createdAt),
      });
    });

    test('rejects metadata belonging to another message', () async {
      var senderLoadCount = 0;
      var commitCount = 0;

      final service = ExistingImageMessageWriteService(
        createMessageId: (_) => 'message-1',
        loadSender: () async {
          senderLoadCount += 1;

          return const ImageMessageSenderIdentity(
            userId: 'user-1',
            email: 'user@example.com',
            name: 'Пользователь',
          );
        },
        createTimestamp: Object.new,
        commit:
            ({
              required String chatId,
              required String messageId,
              required Map<String, dynamic> messageData,
              required String previewText,
              required Object lastMessageAt,
            }) async {
              commitCount += 1;
            },
      );

      final result = service.writeImageMessage(
        chatId: 'chat-1',
        messageId: 'message-1',
        metadata: _imageMetadata(
          chatId: 'chat-1',
          messageId: 'another-message',
        ),
      );

      await expectLater(result, throwsArgumentError);

      expect(senderLoadCount, 0);
      expect(commitCount, 0);
    });

    test('rejects an invalid sender email before commit', () async {
      var commitCount = 0;

      final service = ExistingImageMessageWriteService(
        createMessageId: (_) => 'message-1',
        loadSender: () async {
          return const ImageMessageSenderIdentity(
            userId: 'user-1',
            email: ' user@example.com ',
            name: 'Пользователь',
          );
        },
        createTimestamp: Object.new,
        commit:
            ({
              required String chatId,
              required String messageId,
              required Map<String, dynamic> messageData,
              required String previewText,
              required Object lastMessageAt,
            }) async {
              commitCount += 1;
            },
      );

      final result = service.writeImageMessage(
        chatId: 'chat-1',
        messageId: 'message-1',
        metadata: _imageMetadata(chatId: 'chat-1', messageId: 'message-1'),
      );

      await expectLater(result, throwsStateError);

      expect(commitCount, 0);
    });

    test('requires either all custom callbacks or none', () {
      expect(
        () => ExistingImageMessageWriteService(
          createMessageId: (_) => 'message-1',
        ),
        throwsArgumentError,
      );
    });
  });
}

ImageMessageMetadata _imageMetadata({
  required String chatId,
  required String messageId,
}) {
  final metadata = ImageMessageMetadataMapper.fromMap(
    chatId: chatId,
    messageId: messageId,
    data: _imageMap(chatId: chatId, messageId: messageId),
  );

  if (metadata == null) {
    throw StateError('Test image metadata must be valid.');
  }

  return metadata;
}

Map<String, dynamic> _imageMap({
  required String chatId,
  required String messageId,
}) {
  return {
    'provider': 'firebase',
    'thumbStoragePath': 'chat_media/$chatId/messages/$messageId/v3/thumb.jpg',
    'fullStoragePath': 'chat_media/$chatId/messages/$messageId/v3/full.jpg',
    'thumbSizeBytes': 24 * 1024,
    'fullSizeBytes': 280 * 1024,
    'thumbWidth': 320,
    'thumbHeight': 180,
    'fullWidth': 1600,
    'fullHeight': 900,
    'mimeType': ImageMessageMetadata.supportedMimeType,
    'version': 3,
  };
}
