import 'package:flutter/material.dart';

import '../domain/models/group_avatar.dart';
import '../models/app_user.dart';
import 'avatar/chat_avatar_view.dart';

class ChatAppBarTitle extends StatelessWidget {
  const ChatAppBarTitle({
    super.key,
    this.chatId = '',
    required this.chatName,
    this.subtitle = 'личный чат',
    this.peerUser,
    this.groupAvatar,
    this.isGroup = false,
  });

  final String chatId;
  final String chatName;
  final String subtitle;
  final AppUser? peerUser;
  final GroupAvatar? groupAvatar;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ChatAvatarView(
          chatId: chatId,
          chatName: chatName,
          isPrivateChat: !isGroup,
          peerUser: peerUser,
          groupAvatar: groupAvatar,
          radius: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chatName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
