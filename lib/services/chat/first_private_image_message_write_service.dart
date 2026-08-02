import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/image_message_metadata.dart';
import '../../domain/models/message_content.dart';
import '../../models/app_user.dart';
import 'existing_image_message_write_service.dart';
import 'message_document_mapper.dart';

typedef FirstPrivateImageMessageIdFactory = String Function(String chatId);

typedef FirstPrivateImageMessageSenderLoader =
    Future<ImageMessageSenderIdentity> Function();

typedef FirstPrivateImageMessageTimestampFactory = Object Function();

typedef FirstPrivateImageMessageCommitter =
    Future<void> Function({
      required String chatId,
      required String messageId,
      required String currentUserId,
      required String peerId,
      required Map<String, dynamic> messageData,
      required Map<String, dynamic> newChatData,
      required Map<String, dynamic> existingChatUpdateData,
    });

final class FirstPrivateImageMessageWriteService {
  FirstPrivateImageMessageWriteService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirstPrivateImageMessageIdFactory? createMessageId,
    FirstPrivateImageMessageSenderLoader? loadSender,
    FirstPrivateImageMessageTimestampFactory? createTimestamp,
    FirstPrivateImageMessageCommitter? commit,
  }) {
    final customCallbackCount = [
      createMessageId,
      loadSender,
      createTimestamp,
      commit,
    ].where((callback) => callback != null).length;

    if (customCallbackCount != 0 && customCallbackCount != 4) {
      throw ArgumentError('Provide all custom callbacks or none of them.');
    }

    if (customCallbackCount == 4) {
      if (firestore != null || auth != null) {
        throw ArgumentError(
          'Provide either Firebase dependencies '
          'or custom callbacks, not both.',
        );
      }

      _createMessageId = createMessageId!;
      _loadSender = loadSender!;
      _createTimestamp = createTimestamp!;
      _commit = commit!;
      return;
    }

    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final resolvedAuth = auth ?? FirebaseAuth.instance;

    _createMessageId = (chatId) {
      return resolvedFirestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc()
          .id;
    };

    _loadSender = () {
      return _loadFirebaseSender(
        firestore: resolvedFirestore,
        auth: resolvedAuth,
      );
    };

    _createTimestamp = FieldValue.serverTimestamp;

    _commit =
        ({
          required String chatId,
          required String messageId,
          required String currentUserId,
          required String peerId,
          required Map<String, dynamic> messageData,
          required Map<String, dynamic> newChatData,
          required Map<String, dynamic> existingChatUpdateData,
        }) {
          return _commitFirebaseWrite(
            firestore: resolvedFirestore,
            chatId: chatId,
            messageId: messageId,
            currentUserId: currentUserId,
            peerId: peerId,
            messageData: messageData,
            newChatData: newChatData,
            existingChatUpdateData: existingChatUpdateData,
          );
        };
  }

  late final FirstPrivateImageMessageIdFactory _createMessageId;

  late final FirstPrivateImageMessageSenderLoader _loadSender;

  late final FirstPrivateImageMessageTimestampFactory _createTimestamp;

  late final FirstPrivateImageMessageCommitter _commit;

  String createChatId({required String uploaderId, required String peerId}) {
    _validateIdentifier(value: uploaderId, argumentName: 'uploaderId');

    _validateIdentifier(value: peerId, argumentName: 'peerId');

    if (uploaderId == peerId) {
      throw ArgumentError.value(
        peerId,
        'peerId',
        'Peer ID must differ from uploader ID.',
      );
    }

    final memberIds = [uploaderId, peerId]..sort();

    return memberIds.join('_');
  }

  String createMessageId({required String chatId}) {
    _validateIdentifier(value: chatId, argumentName: 'chatId');

    final messageId = _createMessageId(chatId);

    _validateIdentifier(value: messageId, argumentName: 'messageId');

    return messageId;
  }

  Future<void> writeFirstImageMessage({
    required String uploaderId,
    required AppUser otherUser,
    required String chatId,
    required String messageId,
    required ImageMessageMetadata metadata,
  }) async {
    _validateIdentifier(value: uploaderId, argumentName: 'uploaderId');

    _validateIdentifier(value: otherUser.uid, argumentName: 'otherUser.uid');

    _validateIdentifier(value: chatId, argumentName: 'chatId');

    _validateIdentifier(value: messageId, argumentName: 'messageId');

    if (otherUser.uid == uploaderId) {
      throw ArgumentError.value(
        otherUser.uid,
        'otherUser',
        'Private chat peer must differ from uploader.',
      );
    }

    final expectedChatId = createChatId(
      uploaderId: uploaderId,
      peerId: otherUser.uid,
    );

    if (chatId != expectedChatId) {
      throw ArgumentError.value(
        chatId,
        'chatId',
        'Chat ID does not match private chat members.',
      );
    }

    final content = ImageMessageContent.tryCreate(metadata);

    if (content == null) {
      throw ArgumentError.value(
        metadata,
        'metadata',
        'Image metadata must be complete.',
      );
    }

    if (metadata.messageId != messageId) {
      throw ArgumentError.value(
        metadata,
        'metadata',
        'Image metadata must belong to the target message.',
      );
    }

    final sender = await _loadSender();

    _validateIdentifier(value: sender.userId, argumentName: 'sender.userId');

    if (sender.userId != uploaderId) {
      throw StateError('Authenticated sender does not match uploader ID.');
    }

    if (sender.email.isEmpty || sender.email != sender.email.trim()) {
      throw StateError('Current user must have a non-empty email.');
    }

    final createdAt = _createTimestamp();

    final messageData = MessageDocumentMapper.toCreateMap(
      chatId: chatId,
      messageId: messageId,
      senderId: sender.userId,
      senderEmail: sender.email,
      senderName: sender.name,
      createdAt: createdAt,
      content: content,
    );

    final peerEmail = otherUser.email.trim();

    final memberEmails = <String>{
      sender.email,
      if (peerEmail.isNotEmpty) peerEmail,
    }.toList();

    final newChatData = <String, dynamic>{
      'name': 'private_chat',
      'type': 'private',
      'memberIds': [uploaderId, otherUser.uid],
      'memberEmails': memberEmails,
      'memberRoles': {uploaderId: 'member', otherUser.uid: 'member'},
      'memberStatus': {
        uploaderId: {'status': 'normal'},
        otherUser.uid: {'status': 'normal'},
      },
      'groupSettings': {'messagePermission': 'all'},
      'lastRead': {uploaderId: createdAt},
      'isDissolved': false,
      'createdAt': createdAt,
      'lastMessage': content.previewText,
      'lastMessageAt': createdAt,
      'lastMessageId': messageId,
      'firstMessageId': messageId,
    };

    final existingChatUpdateData = <String, dynamic>{
      'lastMessage': content.previewText,
      'lastMessageAt': createdAt,
      'lastMessageId': messageId,
    };

    await _commit(
      chatId: chatId,
      messageId: messageId,
      currentUserId: uploaderId,
      peerId: otherUser.uid,
      messageData: messageData,
      newChatData: newChatData,
      existingChatUpdateData: existingChatUpdateData,
    );
  }

  static Future<ImageMessageSenderIdentity> _loadFirebaseSender({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw StateError('User must be authenticated.');
    }

    final email = user.email?.trim() ?? '';

    if (email.isEmpty) {
      throw StateError('Current user must have an email.');
    }

    final userSnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final storedName = userSnapshot.data()?['name'];

    final senderName = storedName is String ? storedName : '';

    return ImageMessageSenderIdentity(
      userId: user.uid,
      email: email,
      name: senderName,
    );
  }

  static Future<void> _commitFirebaseWrite({
    required FirebaseFirestore firestore,
    required String chatId,
    required String messageId,
    required String currentUserId,
    required String peerId,
    required Map<String, dynamic> messageData,
    required Map<String, dynamic> newChatData,
    required Map<String, dynamic> existingChatUpdateData,
  }) async {
    final chatReference = firestore.collection('chats').doc(chatId);

    final messageReference = chatReference
        .collection('messages')
        .doc(messageId);

    await firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatReference);

      final chatData = chatSnapshot.data();

      if (chatSnapshot.exists) {
        if (chatData == null) {
          throw StateError('Private chat document has no data.');
        }

        final memberIds = List<String>.from(
          chatData['memberIds'] ?? const <String>[],
        );

        final isExpectedPrivateChat =
            chatData['type'] == 'private' &&
            memberIds.contains(currentUserId) &&
            memberIds.contains(peerId);

        if (!isExpectedPrivateChat) {
          throw StateError(
            'Private chat document has '
            'an invalid structure.',
          );
        }

        transaction.set(messageReference, messageData);

        transaction.update(chatReference, existingChatUpdateData);

        return;
      }

      transaction.set(chatReference, newChatData);

      transaction.set(messageReference, messageData);
    });
  }

  static void _validateIdentifier({
    required String value,
    required String argumentName,
  }) {
    if (value.isEmpty || value != value.trim()) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must be a non-empty trimmed string.',
      );
    }

    if (value.contains('/')) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must not contain a slash.',
      );
    }
  }
}
