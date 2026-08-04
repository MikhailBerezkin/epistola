import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/group_message_reaction.dart';
import 'group_message_reaction_mapper.dart';

typedef GroupMessageReactionCurrentUserIdProvider = String? Function();

typedef GroupMessageReactionCommitter =
    Future<GroupMessageReaction?> Function({
      required String chatId,
      required String messageId,
      required String userId,
      required GroupMessageReaction tappedReaction,
    });

enum GroupMessageReactionWriteStatus { written, skippedUnauthenticated }

final class GroupMessageReactionWriteResult {
  const GroupMessageReactionWriteResult.written(this.reaction)
    : status = GroupMessageReactionWriteStatus.written;

  const GroupMessageReactionWriteResult.skippedUnauthenticated()
    : status = GroupMessageReactionWriteStatus.skippedUnauthenticated,
      reaction = null;

  final GroupMessageReactionWriteStatus status;

  /// Новое состояние пользователя после операции.
  ///
  /// `null` при статусе [GroupMessageReactionWriteStatus.written]
  /// означает, что реакция была снята.
  final GroupMessageReaction? reaction;
}

final class GroupMessageReactionService {
  factory GroupMessageReactionService({
    required GroupMessageReactionCurrentUserIdProvider currentUserIdProvider,
    required GroupMessageReactionCommitter commit,
  }) {
    return GroupMessageReactionService._(
      currentUserIdProvider: currentUserIdProvider,
      commit: commit,
    );
  }

  GroupMessageReactionService._({
    required this._currentUserIdProvider,
    required this._commit,
  });

  factory GroupMessageReactionService.firebase({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;
    final resolvedAuth = auth ?? FirebaseAuth.instance;

    return GroupMessageReactionService(
      currentUserIdProvider: () {
        return resolvedAuth.currentUser?.uid;
      },
      commit:
          ({
            required String chatId,
            required String messageId,
            required String userId,
            required GroupMessageReaction tappedReaction,
          }) {
            final messageReference = resolvedFirestore
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .doc(messageId);

            return resolvedFirestore.runTransaction((transaction) async {
              final messageSnapshot = await transaction.get(messageReference);

              if (!messageSnapshot.exists) {
                throw StateError(
                  'The message does not exist: '
                  'chatId=$chatId, messageId=$messageId.',
                );
              }

              final messageData = messageSnapshot.data();

              if (messageData == null) {
                throw StateError(
                  'The message has no readable data: '
                  'chatId=$chatId, messageId=$messageId.',
                );
              }

              final reactionSnapshot =
                  GroupMessageReactionMapper.fromMessageData(messageData);

              final currentReaction = reactionSnapshot.reactionForUser(userId);

              final nextReaction = GroupMessageReaction.resolveTap(
                current: currentReaction,
                tapped: tappedReaction,
              );

              if (nextReaction == null) {
                transaction.update(messageReference, {
                  'reactions.$userId': FieldValue.delete(),
                });
              } else {
                transaction.update(messageReference, {
                  'reactions.$userId': nextReaction.storageValue,
                });
              }

              return nextReaction;
            });
          },
    );
  }

  final GroupMessageReactionCurrentUserIdProvider _currentUserIdProvider;
  final GroupMessageReactionCommitter _commit;

  Future<GroupMessageReactionWriteResult> toggle({
    required String chatId,
    required String messageId,
    required GroupMessageReaction tappedReaction,
  }) async {
    final normalizedChatId = _normalizeRequiredIdentifier(
      value: chatId,
      argumentName: 'chatId',
    );

    final normalizedMessageId = _normalizeRequiredIdentifier(
      value: messageId,
      argumentName: 'messageId',
    );

    final currentUserId = _currentUserIdProvider()?.trim() ?? '';

    if (!_isValidIdentifier(currentUserId)) {
      return const GroupMessageReactionWriteResult.skippedUnauthenticated();
    }

    final nextReaction = await _commit(
      chatId: normalizedChatId,
      messageId: normalizedMessageId,
      userId: currentUserId,
      tappedReaction: tappedReaction,
    );

    return GroupMessageReactionWriteResult.written(nextReaction);
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
