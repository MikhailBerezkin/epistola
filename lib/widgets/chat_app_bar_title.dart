import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'avatar/user_avatar_view.dart';

class ChatAppBarTitle extends StatelessWidget {
  final String chatName;
  final String subtitle;
  final AppUser? peerUser;
  final bool isGroup;

  const ChatAppBarTitle({
    super.key,
    required this.chatName,
    this.subtitle = 'личный чат',
    this.peerUser,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildAvatar(),
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

  Widget _buildAvatar() {
    final user = peerUser;

    if (!isGroup && user != null) {
      return UserAvatarView(user: user, radius: 18);
    }

    return CircleAvatar(
      radius: 18,
      child: Text(
        chatName.isNotEmpty ? chatName[0].toUpperCase() : '?',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
