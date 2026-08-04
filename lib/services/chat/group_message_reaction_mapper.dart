import '../../domain/models/group_message_reaction.dart';

class GroupMessageReactionSnapshot {
  GroupMessageReactionSnapshot._(
    Map<String, GroupMessageReaction> reactionsByUserId,
  ) : reactionsByUserId = Map.unmodifiable(reactionsByUserId);

  final Map<String, GroupMessageReaction> reactionsByUserId;

  bool get isEmpty => reactionsByUserId.isEmpty;

  GroupMessageReaction? reactionForUser(String userId) {
    return reactionsByUserId[userId];
  }

  int count(GroupMessageReaction reaction) {
    return reactionsByUserId.values.where((value) => value == reaction).length;
  }
}

class GroupMessageReactionMapper {
  const GroupMessageReactionMapper._();

  static GroupMessageReactionSnapshot fromMessageData(
    Map<String, dynamic> data,
  ) {
    final rawReactions = data['reactions'];

    if (rawReactions is! Map) {
      return GroupMessageReactionSnapshot._({});
    }

    final parsedReactions = <String, GroupMessageReaction>{};

    for (final entry in rawReactions.entries) {
      final userId = entry.key;
      final reaction = GroupMessageReaction.tryParse(entry.value);

      if (!_isValidUserId(userId) || reaction == null) {
        continue;
      }

      parsedReactions[userId as String] = reaction;
    }

    return GroupMessageReactionSnapshot._(parsedReactions);
  }

  static bool _isValidUserId(Object? value) {
    return value is String &&
        value.isNotEmpty &&
        value == value.trim() &&
        !value.contains('/');
  }
}
