import 'package:epistola/domain/models/group_message_reaction.dart';
import 'package:epistola/services/chat/group_message_reaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String? currentUserId;
  late GroupMessageReaction? commitResult;
  late Object? commitError;

  late List<
    ({
      String chatId,
      String messageId,
      String userId,
      GroupMessageReaction tappedReaction,
    })
  >
  commits;

  late GroupMessageReactionService service;

  setUp(() {
    currentUserId = 'user-1';
    commitResult = GroupMessageReaction.like;
    commitError = null;

    commits =
        <
          ({
            String chatId,
            String messageId,
            String userId,
            GroupMessageReaction tappedReaction,
          })
        >[];

    service = GroupMessageReactionService(
      currentUserIdProvider: () => currentUserId,
      commit:
          ({
            required String chatId,
            required String messageId,
            required String userId,
            required GroupMessageReaction tappedReaction,
          }) async {
            final error = commitError;

            if (error != null) {
              throw error;
            }

            commits.add((
              chatId: chatId,
              messageId: messageId,
              userId: userId,
              tappedReaction: tappedReaction,
            ));

            return commitResult;
          },
    );
  });

  test('writes a like reaction for the current user', () async {
    final result = await service.toggle(
      chatId: 'group-1',
      messageId: 'message-1',
      tappedReaction: GroupMessageReaction.like,
    );

    expect(result.status, GroupMessageReactionWriteStatus.written);
    expect(result.reaction, GroupMessageReaction.like);

    expect(commits, [
      (
        chatId: 'group-1',
        messageId: 'message-1',
        userId: 'user-1',
        tappedReaction: GroupMessageReaction.like,
      ),
    ]);
  });

  test('writes a dislike reaction for the current user', () async {
    commitResult = GroupMessageReaction.dislike;

    final result = await service.toggle(
      chatId: 'group-1',
      messageId: 'message-1',
      tappedReaction: GroupMessageReaction.dislike,
    );

    expect(result.status, GroupMessageReactionWriteStatus.written);
    expect(result.reaction, GroupMessageReaction.dislike);

    expect(commits.single.tappedReaction, GroupMessageReaction.dislike);
  });

  test('returns null reaction when the existing reaction is removed', () async {
    commitResult = null;

    final result = await service.toggle(
      chatId: 'group-1',
      messageId: 'message-1',
      tappedReaction: GroupMessageReaction.like,
    );

    expect(result.status, GroupMessageReactionWriteStatus.written);
    expect(result.reaction, isNull);
    expect(commits, hasLength(1));
  });

  test('normalizes chat, message, and current user identifiers', () async {
    currentUserId = ' user-1 ';

    await service.toggle(
      chatId: ' group-1 ',
      messageId: ' message-1 ',
      tappedReaction: GroupMessageReaction.like,
    );

    expect(commits.single, (
      chatId: 'group-1',
      messageId: 'message-1',
      userId: 'user-1',
      tappedReaction: GroupMessageReaction.like,
    ));
  });

  test('skips the write when there is no authenticated user', () async {
    currentUserId = null;

    final result = await service.toggle(
      chatId: 'group-1',
      messageId: 'message-1',
      tappedReaction: GroupMessageReaction.like,
    );

    expect(
      result.status,
      GroupMessageReactionWriteStatus.skippedUnauthenticated,
    );
    expect(result.reaction, isNull);
    expect(commits, isEmpty);
  });

  test('skips the write when the current user identifier is invalid', () async {
    for (final invalidUserId in ['', '   ', 'user/1']) {
      currentUserId = invalidUserId;

      final result = await service.toggle(
        chatId: 'group-1',
        messageId: 'message-1',
        tappedReaction: GroupMessageReaction.like,
      );

      expect(
        result.status,
        GroupMessageReactionWriteStatus.skippedUnauthenticated,
      );
    }

    expect(commits, isEmpty);
  });

  test('rejects an invalid chat identifier', () async {
    for (final invalidChatId in ['', '   ', 'group/1']) {
      await expectLater(
        service.toggle(
          chatId: invalidChatId,
          messageId: 'message-1',
          tappedReaction: GroupMessageReaction.like,
        ),
        throwsArgumentError,
      );
    }

    expect(commits, isEmpty);
  });

  test('rejects an invalid message identifier', () async {
    for (final invalidMessageId in ['', '   ', 'message/1']) {
      await expectLater(
        service.toggle(
          chatId: 'group-1',
          messageId: invalidMessageId,
          tappedReaction: GroupMessageReaction.like,
        ),
        throwsArgumentError,
      );
    }

    expect(commits, isEmpty);
  });

  test('propagates a failed commit without hiding the error', () async {
    final error = StateError('write failed');
    commitError = error;

    await expectLater(
      service.toggle(
        chatId: 'group-1',
        messageId: 'message-1',
        tappedReaction: GroupMessageReaction.like,
      ),
      throwsA(same(error)),
    );

    expect(commits, isEmpty);
  });
}
