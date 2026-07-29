import 'package:flutter/material.dart';

import '../../domain/models/group_avatar.dart';
import '../../models/app_user.dart';
import 'group_avatar_view.dart';
import 'user_avatar_view.dart';

class ChatAvatarView extends StatelessWidget {
  const ChatAvatarView({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.isPrivateChat,
    required this.radius,
    this.peerUser,
    this.groupAvatar,
  });

  final String chatId;
  final String chatName;
  final bool isPrivateChat;
  final double radius;
  final AppUser? peerUser;
  final GroupAvatar? groupAvatar;

  @override
  Widget build(BuildContext context) {
    if (isPrivateChat && peerUser != null) {
      return UserAvatarView(
        user: peerUser!,
        radius: radius,
        imageVariant: UserAvatarImageVariant.thumbnail,
      );
    }

    if (!isPrivateChat) {
      return GroupAvatarView(
        chatId: chatId,
        groupName: chatName,
        avatar: groupAvatar,
        radius: radius,
        imageVariant: GroupAvatarImageVariant.thumbnail,
      );
    }

    final firstLetter = chatName.trim().isNotEmpty
        ? chatName.trim()[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      child: Text(
        firstLetter,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
