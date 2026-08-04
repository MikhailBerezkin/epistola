import 'package:epistola/domain/models/group_message_reaction.dart';
import 'package:epistola/services/chat/group_message_reaction_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupMessageReactionMapper.fromMessageData', () {
    test('parses valid reactions', () {
      final snapshot = GroupMessageReactionMapper.fromMessageData({
        'reactions': {'user-1': 'like', 'user-2': 'dislike'},
      });

      expect(snapshot.reactionsByUserId, {
        'user-1': GroupMessageReaction.like,
        'user-2': GroupMessageReaction.dislike,
      });
    });

    test('returns empty snapshot when reactions field is missing', () {
      final snapshot = GroupMessageReactionMapper.fromMessageData({});

      expect(snapshot.isEmpty, isTrue);
    });

    test('returns empty snapshot when reactions field is not a map', () {
      final snapshot = GroupMessageReactionMapper.fromMessageData({
        'reactions': 'like',
      });

      expect(snapshot.isEmpty, isTrue);
    });

    test('ignores invalid user identifiers', () {
      final snapshot = GroupMessageReactionMapper.fromMessageData({
        'reactions': {
          '': 'like',
          ' user-1': 'like',
          'user-2 ': 'dislike',
          'user/3': 'like',
          4: 'dislike',
          'valid-user': 'like',
        },
      });

      expect(snapshot.reactionsByUserId, {
        'valid-user': GroupMessageReaction.like,
      });
    });

    test('ignores unsupported reaction values', () {
      final snapshot = GroupMessageReactionMapper.fromMessageData({
        'reactions': {
          'user-1': 'love',
          'user-2': '',
          'user-3': null,
          'user-4': 1,
          'user-5': 'dislike',
        },
      });

      expect(snapshot.reactionsByUserId, {
        'user-5': GroupMessageReaction.dislike,
      });
    });

    test('returns reaction for the requested user', () {
      final snapshot = GroupMessageReactionMapper.fromMessageData({
        'reactions': {'user-1': 'like', 'user-2': 'dislike'},
      });

      expect(snapshot.reactionForUser('user-2'), GroupMessageReaction.dislike);
      expect(snapshot.reactionForUser('user-3'), isNull);
    });

    test('counts likes and dislikes separately', () {
      final snapshot = GroupMessageReactionMapper.fromMessageData({
        'reactions': {'user-1': 'like', 'user-2': 'like', 'user-3': 'dislike'},
      });

      expect(snapshot.count(GroupMessageReaction.like), 2);
      expect(snapshot.count(GroupMessageReaction.dislike), 1);
    });

    test('exposes an unmodifiable reactions map', () {
      final snapshot = GroupMessageReactionMapper.fromMessageData({
        'reactions': {'user-1': 'like'},
      });

      expect(() {
        snapshot.reactionsByUserId['user-2'] = GroupMessageReaction.dislike;
      }, throwsUnsupportedError);
    });
  });
}
