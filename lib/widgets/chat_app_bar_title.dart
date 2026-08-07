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
    this.onTap,
  });

  final String chatId;
  final String chatName;
  final String subtitle;
  final AppUser? peerUser;
  final GroupAvatar? groupAvatar;
  final bool isGroup;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: onTap == null ? null : 'Открыть информацию о чате',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
