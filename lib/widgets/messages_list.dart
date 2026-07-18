import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import 'message_bubble.dart';

class MessagesList extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> memberRoles;
  final Timestamp? visibleAfter;

  const MessagesList({
    super.key,
    required this.chatId,
    required this.memberRoles,
    this.visibleAfter,
  });

  @override
  State<MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<MessagesList> {
  final chatService = ChatService();
  final scrollController = ScrollController();

  int lastMessageCount = 0;

  String formatMessageTime(dynamic createdAt) {
    if (createdAt == null || createdAt is! Timestamp) return '';

    final dateTime = createdAt.toDate();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      final bottom = scrollController.position.maxScrollExtent;

      if (animated) {
        scrollController.animateTo(
          bottom,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        scrollController.jumpTo(bottom);
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: chatService.getMessages(
        widget.chatId,
        after: widget.visibleAfter,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            lastMessageCount == 0) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return const Center(child: Text('Сообщений пока нет'));
        }

        if (messages.length != lastMessageCount) {
          final isFirstLoad = lastMessageCount == 0;

          lastMessageCount = messages.length;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!scrollController.hasClients) return;

            final position = scrollController.position;
            final bottom = position.maxScrollExtent;
            final distanceFromBottom = bottom - position.pixels;
            final isNearBottom = distanceFromBottom < 180;

            if (isFirstLoad) {
              scrollController.jumpTo(bottom);
              return;
            }

            if (isNearBottom) {
              scrollController.animateTo(
                bottom,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
              );
            }
          });
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final data = message.data() as Map<String, dynamic>;

            final text = data['text'] ?? '';
            final senderId = data['senderId'];
            final senderName =
                data['senderName'] ?? data['senderEmail'] ?? 'Пользователь';
            final createdAt = data['createdAt'];
            final timeText = formatMessageTime(createdAt);
            final isMe = senderId == currentUser?.uid;
            final senderRole = widget.memberRoles[senderId] ?? 'member';

            return MessageBubble(
              text: text,
              senderName: senderName,
              senderRole: senderRole,
              timeText: timeText,
              isMe: isMe,
            );
          },
        );
      },
    );
  }
}
