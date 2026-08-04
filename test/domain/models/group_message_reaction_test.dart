import 'package:epistola/domain/models/group_message_reaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupMessageReaction.tryParse', () {
    test('parses like', () {
      expect(GroupMessageReaction.tryParse('like'), GroupMessageReaction.like);
    });

    test('parses dislike', () {
      expect(
        GroupMessageReaction.tryParse('dislike'),
        GroupMessageReaction.dislike,
      );
    });

    test('rejects unsupported values', () {
      expect(GroupMessageReaction.tryParse('love'), isNull);
      expect(GroupMessageReaction.tryParse(''), isNull);
      expect(GroupMessageReaction.tryParse(null), isNull);
      expect(GroupMessageReaction.tryParse(1), isNull);
    });
  });

  group('GroupMessageReaction.resolveTap', () {
    test('adds like when there is no current reaction', () {
      expect(
        GroupMessageReaction.resolveTap(
          current: null,
          tapped: GroupMessageReaction.like,
        ),
        GroupMessageReaction.like,
      );
    });

    test('removes like when like is tapped again', () {
      expect(
        GroupMessageReaction.resolveTap(
          current: GroupMessageReaction.like,
          tapped: GroupMessageReaction.like,
        ),
        isNull,
      );
    });

    test('replaces dislike with like', () {
      expect(
        GroupMessageReaction.resolveTap(
          current: GroupMessageReaction.dislike,
          tapped: GroupMessageReaction.like,
        ),
        GroupMessageReaction.like,
      );
    });

    test('adds dislike when there is no current reaction', () {
      expect(
        GroupMessageReaction.resolveTap(
          current: null,
          tapped: GroupMessageReaction.dislike,
        ),
        GroupMessageReaction.dislike,
      );
    });

    test('removes dislike when dislike is tapped again', () {
      expect(
        GroupMessageReaction.resolveTap(
          current: GroupMessageReaction.dislike,
          tapped: GroupMessageReaction.dislike,
        ),
        isNull,
      );
    });

    test('replaces like with dislike', () {
      expect(
        GroupMessageReaction.resolveTap(
          current: GroupMessageReaction.like,
          tapped: GroupMessageReaction.dislike,
        ),
        GroupMessageReaction.dislike,
      );
    });
  });
}
