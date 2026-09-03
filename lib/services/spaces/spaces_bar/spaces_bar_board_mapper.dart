import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/spaces_bar_board.dart';
import '../../../domain/models/spaces_bar_message.dart';

final class SpacesBarBoardMapper {
  const SpacesBarBoardMapper._();

  static const int currentSchemaVersion = 1;

  static const String schemaVersionField = 'schemaVersion';
  static const String revisionField = 'revision';
  static const String messagesField = 'messages';
  static const String updatedAtField = 'updatedAt';

  static const String textField = 'text';
  static const String lifetimeField = 'lifetime';
  static const String createdByUserIdField = 'createdByUserId';
  static const String createdAtField = 'createdAt';

  static const Set<String> _allowedBoardFields = <String>{
    schemaVersionField,
    revisionField,
    messagesField,
    updatedAtField,
  };

  static const Set<String> _allowedMessageFields = <String>{
    textField,
    lifetimeField,
    createdByUserIdField,
    createdAtField,
  };

  static SpacesBarBoard? fromMap(Map<String, dynamic> data) {
    if (data.length != _allowedBoardFields.length ||
        !data.keys.every(_allowedBoardFields.contains)) {
      return null;
    }

    final rawSchemaVersion = data[schemaVersionField];
    final rawRevision = data[revisionField];
    final rawMessages = data[messagesField];
    final rawUpdatedAt = data[updatedAtField];

    if (rawSchemaVersion is! int ||
        rawSchemaVersion != currentSchemaVersion ||
        rawRevision is! int ||
        rawRevision < 0 ||
        rawMessages is! Map ||
        rawUpdatedAt is! Timestamp) {
      return null;
    }

    final messages = <SpacesBarMessage>[];

    for (final entry in rawMessages.entries) {
      final rawMessageId = entry.key;
      final rawMessageData = entry.value;

      if (rawMessageId is! String ||
          !_isCanonicalId(rawMessageId) ||
          rawMessageData is! Map) {
        return null;
      }

      final messageData = Map<String, dynamic>.from(rawMessageData);

      if (messageData.length != _allowedMessageFields.length ||
          !messageData.keys.every(_allowedMessageFields.contains)) {
        return null;
      }

      final rawText = messageData[textField];
      final rawLifetime = messageData[lifetimeField];
      final rawCreatedByUserId = messageData[createdByUserIdField];
      final rawCreatedAt = messageData[createdAtField];

      if (rawText is! String ||
          rawText.isEmpty ||
          rawText.trim() != rawText ||
          rawText.length > SpacesBarMessage.maxTextLength ||
          rawLifetime is! String ||
          rawCreatedByUserId is! String ||
          !_isCanonicalId(rawCreatedByUserId) ||
          rawCreatedAt is! Timestamp) {
        return null;
      }

      final lifetime = SpacesBarMessageLifetime.tryParse(rawLifetime);

      if (lifetime == null) {
        return null;
      }

      final message = SpacesBarMessage.tryCreate(
        id: rawMessageId,
        text: rawText,
        lifetime: lifetime,
        createdByUserId: rawCreatedByUserId,
        createdAt: rawCreatedAt.toDate().toUtc(),
      );

      if (message == null) {
        return null;
      }

      messages.add(message);
    }

    return SpacesBarBoard.tryCreate(revision: rawRevision, messages: messages);
  }

  static Map<String, dynamic> toWriteMap(
    SpacesBarBoard board, {
    String? serverCreatedAtMessageId,
  }) {
    if (serverCreatedAtMessageId != null &&
        !board.messages.any(
          (message) => message.id == serverCreatedAtMessageId,
        )) {
      throw ArgumentError.value(
        serverCreatedAtMessageId,
        'serverCreatedAtMessageId',
        'Message must exist in the board.',
      );
    }

    return <String, dynamic>{
      schemaVersionField: currentSchemaVersion,
      revisionField: board.revision,
      messagesField: <String, dynamic>{
        for (final message in board.messages)
          message.id: <String, dynamic>{
            textField: message.text,
            lifetimeField: message.lifetime.storageValue,
            createdByUserIdField: message.createdByUserId,
            createdAtField: message.id == serverCreatedAtMessageId
                ? FieldValue.serverTimestamp()
                : Timestamp.fromDate(message.createdAt.toUtc()),
          },
      },
      updatedAtField: FieldValue.serverTimestamp(),
    };
  }

  static bool _isCanonicalId(String value) {
    final normalized = value.trim();

    return normalized.isNotEmpty &&
        normalized == value &&
        !normalized.contains('/');
  }
}
