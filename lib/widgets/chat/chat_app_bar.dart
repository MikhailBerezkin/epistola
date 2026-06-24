import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../helpers/status_helper.dart';
import '../../screens/group_info_screen.dart';
import '../chat_app_bar_title.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String chatId;
  final String chatName;

  const ChatAppBar({super.key, required this.chatId, required this.chatName});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;

        final currentUser = FirebaseAuth.instance.currentUser;

        final chatType = data?['type'] ?? 'private';
        final memberIds = (data?['memberIds'] as List?) ?? [];
        final memberStatus =
            (data?['memberStatus'] as Map<String, dynamic>?) ?? {};

        final isGroup = chatType == 'group';

        final currentStatusData =
            (memberStatus[currentUser?.uid] as Map<String, dynamic>?) ??
            {'status': 'normal'};

        final currentStatus = currentStatusData['status'] ?? 'normal';
        final currentStatusIsActive = StatusHelper.isActive(currentStatusData);

        final isBanned =
            isGroup && currentStatus == 'banned' && currentStatusIsActive;

        final subtitle = isGroup
            ? '${memberIds.length} участников'
            : 'личный чат';

        return AppBar(
          titleSpacing: 0,
          title: ChatAppBarTitle(chatName: chatName, subtitle: subtitle),
          actions: [
            if (isGroup && !isBanned)
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupInfoScreen(chatId: chatId),
                    ),
                  );
                },
                icon: const Icon(Icons.more_vert),
                tooltip: 'Настройки группы',
              ),
          ],
        );
      },
    );
  }
}
