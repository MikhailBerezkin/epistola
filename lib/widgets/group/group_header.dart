import 'package:flutter/material.dart';

import '../../domain/models/group_avatar.dart';
import '../avatar/group_avatar_view.dart';

class GroupHeader extends StatelessWidget {
  const GroupHeader({
    super.key,
    required this.chatId,
    required this.groupName,
    required this.memberCount,
    this.avatar,
    this.onAvatarTap,
  });

  final String chatId;
  final String groupName;
  final int memberCount;
  final GroupAvatar? avatar;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onAvatarTap,
            customBorder: const CircleBorder(),
            child: GroupAvatarView(
              chatId: chatId,
              groupName: groupName,
              avatar: avatar,
              radius: 48,
              imageVariant: GroupAvatarImageVariant.full,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          groupName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '$memberCount участников',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
