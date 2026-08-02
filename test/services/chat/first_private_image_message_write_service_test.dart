import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/models/app_user.dart';
import 'package:epistola/services/chat/existing_image_message_write_service.dart';
import 'package:epistola/services/chat/first_private_image_message_write_service.dart';
import 'package:epistola/services/chat/image_message_metadata_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirstPrivateImageMessageWriteService', () {
    test('creates canonical private chat and message IDs', () {
      String? receivedChatId;

      final service = _createService(
        createMessageId: (chatId) {
          receivedChatId = chatId;

          return 'message-1';
        },
      );

      final chatId = service.createChatId(
        uploaderId: 'user-2',
        peerId: 'user-1',
      );

      expect(chatId, 'user-1_user-2');

      final messageId = service.createMessageId(chatId: chatId);

      expect(messageId, 'message-1');
      expect(receivedChatId, 'user-1_user-2');
    });

    test('builds a new private chat and first image message', () async {
      final createdAt = Object();

      Map<String, dynamic>? committedMessageData;
      Map<String, dynamic>? committedNewChatData;
      Map<String, dynamic>? committedExistingChatUpdateData;

      String? committedChatId;
      String? committedMessageId;
      String? committedCurrentUserId;
      String? committedPeerId;

      final service = FirstPrivateImageMessageWriteService(
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
              required String currentUserId,
              required String peerId,
              required Map<String, dynamic> messageData,
              required Map<String, dynamic> newChatData,
              required Map<String, dynamic> existingChatUpdateData,
            }) async {
              committedChatId = chatId;
              committedMessageId = messageId;
              committedCurrentUserId = currentUserId;
              committedPeerId = peerId;
              committedMessageData = messageData;
              committedNewChatData = newChatData;
              committedExistingChatUpdateData = existingChatUpdateData;
            },
      );

      await service.writeFirstImageMessage(
        uploaderId: 'user-1',
        otherUser: _peerUser(),
        chatId: 'user-1_user-2',
        messageId: 'message-1',
        metadata: _imageMetadata(
          chatId: 'user-1_user-2',
          messageId: 'message-1',
        ),
      );

      expect(committedChatId, 'user-1_user-2');

      expect(committedMessageId, 'message-1');

      expect(committedCurrentUserId, 'user-1');

      expect(committedPeerId, 'user-2');

      expect(committedMessageData, {
        'messageType': 'image',
        'text': '',
        'image': _imageMap(chatId: 'user-1_user-2', messageId: 'message-1'),
        'senderId': 'user-1',
        'senderEmail': 'user@example.com',
        'senderName': 'Пользователь',
        'createdAt': same(createdAt),
      });

      final newChatData = committedNewChatData!;

      expect(newChatData['name'], 'private_chat');

      expect(newChatData['type'], 'private');

      expect(newChatData['memberIds'], ['user-1', 'user-2']);

      expect(newChatData['memberEmails'], [
        'user@example.com',
        'peer@example.com',
      ]);

      expect(newChatData['memberRoles'], {
        'user-1': 'member',
        'user-2': 'member',
      });

      expect(newChatData['memberStatus'], {
        'user-1': {'status': 'normal'},
        'user-2': {'status': 'normal'},
      });

      expect(newChatData['groupSettings'], {'messagePermission': 'all'});

      expect(newChatData['lastRead'], {'user-1': same(createdAt)});

      expect(newChatData['isDissolved'], isFalse);

      expect(newChatData['createdAt'], same(createdAt));

      expect(newChatData['lastMessage'], 'Фотография');

      expect(newChatData['lastMessageAt'], same(createdAt));

      expect(newChatData['lastMessageId'], 'message-1');

      expect(newChatData['firstMessageId'], 'message-1');

      expect(committedExistingChatUpdateData, {
        'lastMessage': 'Фотография',
        'lastMessageAt': same(createdAt),
        'lastMessageId': 'message-1',
      });
    });

    test('rejects metadata belonging to another message', () async {
      var senderLoadCount = 0;
      var commitCount = 0;

      final service = FirstPrivateImageMessageWriteService(
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
              required String currentUserId,
              required String peerId,
              required Map<String, dynamic> messageData,
              required Map<String, dynamic> newChatData,
              required Map<String, dynamic> existingChatUpdateData,
            }) async {
              commitCount += 1;
            },
      );

      final result = service.writeFirstImageMessage(
        uploaderId: 'user-1',
        otherUser: _peerUser(),
        chatId: 'user-1_user-2',
        messageId: 'message-1',
        metadata: _imageMetadata(
          chatId: 'user-1_user-2',
          messageId: 'another-message',
        ),
      );

      await expectLater(result, throwsArgumentError);

      expect(senderLoadCount, 0);
      expect(commitCount, 0);
    });

    test('rejects a sender that differs from uploader', () async {
      var commitCount = 0;

      final service = FirstPrivateImageMessageWriteService(
        createMessageId: (_) => 'message-1',
        loadSender: () async {
          return const ImageMessageSenderIdentity(
            userId: 'another-user',
            email: 'user@example.com',
            name: 'Пользователь',
          );
        },
        createTimestamp: Object.new,
        commit:
            ({
              required String chatId,
              required String messageId,
              required String currentUserId,
              required String peerId,
              required Map<String, dynamic> messageData,
              required Map<String, dynamic> newChatData,
              required Map<String, dynamic> existingChatUpdateData,
            }) async {
              commitCount += 1;
            },
      );

      final result = service.writeFirstImageMessage(
        uploaderId: 'user-1',
        otherUser: _peerUser(),
        chatId: 'user-1_user-2',
        messageId: 'message-1',
        metadata: _imageMetadata(
          chatId: 'user-1_user-2',
          messageId: 'message-1',
        ),
      );

      await expectLater(result, throwsStateError);

      expect(commitCount, 0);
    });

    test('requires either all custom callbacks or none', () {
      expect(
        () => FirstPrivateImageMessageWriteService(
          createMessageId: (_) => 'message-1',
        ),
        throwsArgumentError,
      );
    });
  });
}

FirstPrivateImageMessageWriteService _createService({
  required FirstPrivateImageMessageIdFactory createMessageId,
}) {
  return FirstPrivateImageMessageWriteService(
    createMessageId: createMessageId,
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
          required String currentUserId,
          required String peerId,
          required Map<String, dynamic> messageData,
          required Map<String, dynamic> newChatData,
          required Map<String, dynamic> existingChatUpdateData,
        }) async {},
  );
}

AppUser _peerUser() {
  return const AppUser(
    uid: 'user-2',
    email: 'peer@example.com',
    name: 'Собеседник',
    phone: '',
    about: '',
  );
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
    'thumbStoragePath':
        'chat_media/$chatId/'
        'messages/$messageId/v2/thumb.jpg',
    'fullStoragePath':
        'chat_media/$chatId/'
        'messages/$messageId/v2/full.jpg',
    'thumbSizeBytes': 24 * 1024,
    'fullSizeBytes': 280 * 1024,
    'thumbWidth': 320,
    'thumbHeight': 240,
    'fullWidth': 1600,
    'fullHeight': 1200,
    'mimeType': ImageMessageMetadata.supportedMimeType,
    'version': 2,
  };
}
