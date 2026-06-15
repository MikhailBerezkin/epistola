import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/chat_service.dart';
import '../widgets/chat_app_bar_title.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatScreen({super.key, required this.chatId, required this.chatName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageController = TextEditingController();
  final chatService = ChatService();
  final ScrollController scrollController = ScrollController();

  int lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    chatService.markChatAsRead(widget.chatId);
  }

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

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty) return;

    HapticFeedback.selectionClick();

    messageController.clear();

    await chatService.sendMessage(chatId: widget.chatId, text: text);

    scrollToBottom();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .snapshots(),
      builder: (context, chatSnapshot) {
        final chatData = chatSnapshot.data?.data() as Map<String, dynamic>?;

        final chatType = chatData?['type'] ?? 'private';
        final memberIds = (chatData?['memberIds'] as List?) ?? [];
        final isGroup = chatType == 'group';

        final subtitle = isGroup
            ? '${memberIds.length} участников'
            : 'личный чат';

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: ChatAppBarTitle(
              chatName: widget.chatName,
              subtitle: subtitle,
            ),
            actions: [
              if (isGroup)
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    debugPrint('Открыть настройки группы');
                  },
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Настройки группы',
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: chatService.getMessages(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Ошибка: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data?.docs ?? [];

                    if (messages.isEmpty) {
                      return const Center(child: Text('Сообщений пока нет'));
                    }

                    if (messages.length != lastMessageCount) {
                      final isFirstLoad = lastMessageCount == 0;
                      lastMessageCount = messages.length;

                      scrollToBottom(animated: !isFirstLoad);
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
                            data['senderName'] ??
                            data['senderEmail'] ??
                            'Пользователь';
                        final createdAt = data['createdAt'];
                        final timeText = formatMessageTime(createdAt);
                        final isMe = senderId == currentUser?.uid;

                        return MessageBubble(
                          text: text,
                          senderName: senderName,
                          timeText: timeText,
                          isMe: isMe,
                        );
                      },
                    );
                  },
                ),
              ),
              MessageInput(controller: messageController, onSend: sendMessage),
            ],
          ),
        );
      },
    );
  }
}
