import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../helpers/status_helper.dart';
import '../../models/app_user.dart';
import '../../screens/group_info_screen.dart';
import '../../services/avatar/group_avatar_metadata_mapper.dart';
import '../chat_app_bar_title.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.chatId,
    required this.chatName,
    this.peerUser,
    this.peerIsTyping = false,
    this.chatData,
    this.onIdentityTap,
  });

  final String chatId;
  final String chatName;
  final AppUser? peerUser;
  final bool peerIsTyping;
  final Map<String, dynamic>? chatData;
  final VoidCallback? onIdentityTap;

  @override
  Size get preferredSize {
    return const Size.fromHeight(kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    final data = chatData;

    final currentUser = FirebaseAuth.instance.currentUser;

    final chatType = data?['type'] ?? 'private';

    final memberIds = (data?['memberIds'] as List?) ?? const [];

    final memberStatus =
        (data?['memberStatus'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final isGroup = chatType == 'group';

    final groupAvatar = isGroup && data != null
        ? GroupAvatarMetadataMapper.fromMap(data: data, chatId: chatId)
        : null;

    final currentStatusData =
        (memberStatus[currentUser?.uid] as Map<String, dynamic>?) ??
        <String, dynamic>{'status': 'normal'};

    final currentStatus = currentStatusData['status'] ?? 'normal';

    final currentStatusIsActive = StatusHelper.isActive(currentStatusData);

    final isBanned =
        isGroup && currentStatus == 'banned' && currentStatusIsActive;

    final subtitle = _resolveSubtitle(
      isGroup: isGroup,
      memberCount: memberIds.length,
    );

    return AppBar(
      titleSpacing: 0,
      title: ChatAppBarTitle(
        chatId: chatId,
        chatName: chatName,
        subtitle: subtitle,
        peerUser: isGroup ? null : peerUser,
        groupAvatar: groupAvatar,
        isGroup: isGroup,
        onTap: onIdentityTap,
      ),
      actions: [
        if (isGroup && !isBanned)
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) {
                    return GroupInfoScreen(chatId: chatId);
                  },
                ),
              );
            },
            icon: const Icon(Icons.more_vert),
            tooltip: 'Настройки группы',
          ),
      ],
    );
  }

  String _resolveSubtitle({required bool isGroup, required int memberCount}) {
    if (isGroup) {
      return '$memberCount участников';
    }

    if (!peerIsTyping) {
      return 'личный чат';
    }

    final peerName = peerUser?.name.trim() ?? '';

    final effectivePeerName = peerName.isNotEmpty ? peerName : chatName.trim();

    if (effectivePeerName.isEmpty) {
      return 'Пишет…';
    }

    return '$effectivePeerName пишет…';
  }
}
