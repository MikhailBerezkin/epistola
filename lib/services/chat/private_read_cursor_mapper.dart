import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/private_read_cursor.dart';

final class PrivateReadCursorMapper {
  const PrivateReadCursorMapper._();

  static const String fieldName = 'privateReadState';

  static PrivateReadCursor? fromChatData({
    required Map<String, dynamic> chatData,
    required String userId,
  }) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty || normalizedUserId.contains('/')) {
      return null;
    }

    final readState = chatData[fieldName];

    if (readState is! Map) {
      return null;
    }

    final userReadState = readState[normalizedUserId];

    if (userReadState is! Map) {
      return null;
    }

    final messageId = userReadState['messageId'];
    final messageCreatedAt = userReadState['messageCreatedAt'];

    if (messageId is! String || messageCreatedAt is! Timestamp) {
      return null;
    }

    return PrivateReadCursor.tryCreate(
      messageId: messageId,
      messageCreatedAt: messageCreatedAt.toDate(),
    );
  }
}
