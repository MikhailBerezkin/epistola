import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/image_message_metadata.dart';
import '../../domain/models/message_content.dart';
import 'message_document_mapper.dart';

final class ImageMessageSenderIdentity {
  const ImageMessageSenderIdentity({
    required this.userId,
    required this.email,
    required this.name,
  });

  final String userId;
  final String email;
  final String name;
}

typedef ExistingImageMessageIdFactory = String Function(String chatId);

typedef ExistingImageMessageSenderLoader =
    Future<ImageMessageSenderIdentity> Function();

typedef ExistingImageMessageTimestampFactory = Object Function();

typedef ExistingImageMessageCommitter =
    Future<void> Function({
      required String chatId,
      required String messageId,
      required Map<String, dynamic> messageData,
      required String previewText,
      required Object lastMessageAt,
    });

final class ExistingImageMessageWriteService {
  ExistingImageMessageWriteService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ExistingImageMessageIdFactory? createMessageId,
    ExistingImageMessageSenderLoader? loadSender,
    ExistingImageMessageTimestampFactory? createTimestamp,
    ExistingImageMessageCommitter? commit,
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
          required Map<String, dynamic> messageData,
          required String previewText,
          required Object lastMessageAt,
        }) {
          return _commitFirebaseWrite(
            firestore: resolvedFirestore,
            chatId: chatId,
            messageId: messageId,
            messageData: messageData,
            previewText: previewText,
            lastMessageAt: lastMessageAt,
          );
        };
  }

  late final ExistingImageMessageIdFactory _createMessageId;

  late final ExistingImageMessageSenderLoader _loadSender;

  late final ExistingImageMessageTimestampFactory _createTimestamp;

  late final ExistingImageMessageCommitter _commit;

  String createMessageId({required String chatId}) {
    _validateIdentifier(value: chatId, argumentName: 'chatId');

    final messageId = _createMessageId(chatId);

    _validateIdentifier(value: messageId, argumentName: 'messageId');

    return messageId;
  }

  Future<void> writeImageMessage({
    required String chatId,
    required String messageId,
    required ImageMessageMetadata metadata,
  }) async {
    _validateIdentifier(value: chatId, argumentName: 'chatId');

    _validateIdentifier(value: messageId, argumentName: 'messageId');

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

    await _commit(
      chatId: chatId,
      messageId: messageId,
      messageData: messageData,
      previewText: content.previewText,
      lastMessageAt: createdAt,
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
    required Map<String, dynamic> messageData,
    required String previewText,
    required Object lastMessageAt,
  }) async {
    final chatReference = firestore.collection('chats').doc(chatId);

    final messageReference = chatReference
        .collection('messages')
        .doc(messageId);

    final batch = firestore.batch();

    batch.set(messageReference, messageData);

    batch.update(chatReference, {
      'lastMessage': previewText,
      'lastMessageAt': lastMessageAt,
      'lastMessageId': messageId,
    });

    await batch.commit();
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
