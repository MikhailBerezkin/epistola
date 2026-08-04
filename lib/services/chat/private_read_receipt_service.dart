import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/private_read_cursor.dart';

typedef PrivateReadCurrentUserIdProvider = String? Function();

typedef PrivateReadReceiptCommitter =
    Future<void> Function({
      required String chatId,
      required String userId,
      required PrivateReadCursor cursor,
    });

enum PrivateReadReceiptWriteResult {
  written,
  skippedUnauthenticated,
  skippedNotAdvanced,
}

final class PrivateReadReceiptService {
  PrivateReadReceiptService({
    required this._currentUserIdProvider,
    required this._commit,
  });

  factory PrivateReadReceiptService.firebase({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final resolvedAuth = auth ?? FirebaseAuth.instance;

    return PrivateReadReceiptService(
      currentUserIdProvider: () {
        return resolvedAuth.currentUser?.uid;
      },
      commit:
          ({
            required String chatId,
            required String userId,
            required PrivateReadCursor cursor,
          }) {
            return resolvedFirestore.collection('chats').doc(chatId).update({
              'lastRead.$userId': FieldValue.serverTimestamp(),
              'privateReadState.$userId': {
                'messageId': cursor.messageId,
                'messageCreatedAt': Timestamp.fromDate(cursor.messageCreatedAt),
                'readAt': FieldValue.serverTimestamp(),
              },
            });
          },
    );
  }

  final PrivateReadCurrentUserIdProvider _currentUserIdProvider;
  final PrivateReadReceiptCommitter _commit;

  final Map<String, PrivateReadCursor> _lastCommittedByChat =
      <String, PrivateReadCursor>{};

  Future<PrivateReadReceiptWriteResult> markRead({
    required String chatId,
    required PrivateReadCursor cursor,
  }) async {
    final normalizedChatId = _normalizeRequiredIdentifier(
      value: chatId,
      argumentName: 'chatId',
    );

    final currentUserId = _currentUserIdProvider()?.trim() ?? '';

    if (!_isValidIdentifier(currentUserId)) {
      return PrivateReadReceiptWriteResult.skippedUnauthenticated;
    }

    final previousCursor = _lastCommittedByChat[normalizedChatId];

    final hasAlreadyCoveredCursor =
        previousCursor?.covers(
          messageId: cursor.messageId,
          messageCreatedAt: cursor.messageCreatedAt,
        ) ==
        true;

    if (hasAlreadyCoveredCursor) {
      return PrivateReadReceiptWriteResult.skippedNotAdvanced;
    }

    await _commit(
      chatId: normalizedChatId,
      userId: currentUserId,
      cursor: cursor,
    );

    _lastCommittedByChat[normalizedChatId] = cursor;

    return PrivateReadReceiptWriteResult.written;
  }

  static bool _isValidIdentifier(String value) {
    return value.isNotEmpty && value == value.trim() && !value.contains('/');
  }

  static String _normalizeRequiredIdentifier({
    required String value,
    required String argumentName,
  }) {
    final normalizedValue = value.trim();

    if (!_isValidIdentifier(normalizedValue)) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must be a non-empty string without slashes.',
      );
    }

    return normalizedValue;
  }
}
