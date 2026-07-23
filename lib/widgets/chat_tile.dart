import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class ChatTile extends StatelessWidget {
  final String chatId;
  final String chatName;
  final String lastMessage;
  final dynamic lastMessageAt;
  final bool showLastMessagePreview;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatTile({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.lastMessage,
    required this.lastMessageAt,
    this.showLastMessagePreview = true,
    required this.onTap,
    this.onLongPress,
  });

  String formatChatTime(dynamic value) {
    if (value == null || value is! Timestamp) return '';

    final dateTime = value.toDate();
    final now = DateTime.now();

    final isToday =
        dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    if (isToday) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$day.$month';
  }

  @override
  Widget build(BuildContext context) {
    final firstLetter = chatName.isNotEmpty ? chatName[0].toUpperCase() : '?';
    final timeText = showLastMessagePreview
        ? formatChatTime(lastMessageAt)
        : '';

    return Card(
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: CircleAvatar(
          child: Text(
            firstLetter,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                chatName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (timeText.isNotEmpty)
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: showLastMessagePreview
                  ? Text(
                      lastMessage.isEmpty ? 'Сообщений пока нет' : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : const SizedBox.shrink(),
            ),
            FutureBuilder<int>(
              future: ChatService().getUnreadCount(chatId),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;

                if (unreadCount == 0) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
