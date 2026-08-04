import 'package:flutter/material.dart';

import '../../domain/models/group_message_reaction.dart';

class GroupMessageReactionBar extends StatelessWidget {
  const GroupMessageReactionBar({
    super.key,
    required this.likeCount,
    required this.dislikeCount,
    required this.selectedReaction,
  }) : assert(likeCount >= 0),
       assert(dislikeCount >= 0);

  static const likeStatKey = ValueKey<String>(
    'group-message-reaction-like-stat',
  );

  static const dislikeStatKey = ValueKey<String>(
    'group-message-reaction-dislike-stat',
  );

  final int likeCount;
  final int dislikeCount;
  final GroupMessageReaction? selectedReaction;

  @override
  Widget build(BuildContext context) {
    if (likeCount == 0 && dislikeCount == 0) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (likeCount > 0)
          _ReactionStat(
            statKey: likeStatKey,
            emoji: '👍',
            count: likeCount,
            semanticsLabel: 'Нравится',
            isSelected: selectedReaction == GroupMessageReaction.like,
          ),
        if (dislikeCount > 0)
          _ReactionStat(
            statKey: dislikeStatKey,
            emoji: '👎',
            count: dislikeCount,
            semanticsLabel: 'Не нравится',
            isSelected: selectedReaction == GroupMessageReaction.dislike,
          ),
      ],
    );
  }
}

class _ReactionStat extends StatelessWidget {
  const _ReactionStat({
    required this.statKey,
    required this.emoji,
    required this.count,
    required this.semanticsLabel,
    required this.isSelected,
  });

  final Key statKey;
  final String emoji;
  final int count;
  final String semanticsLabel;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final textColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Semantics(
      key: statKey,
      selected: isSelected,
      label: '$semanticsLabel: $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
