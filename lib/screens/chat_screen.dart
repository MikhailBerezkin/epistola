import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../services/chat_service.dart';
import '../widgets/messages_list.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/message_input_area.dart';
import '../widgets/chat/banned_overlay.dart';

import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    chatService.markChatAsRead(widget.chatId);
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty) return;

    HapticFeedback.selectionClick();
    messageController.clear();

    await chatService.sendMessage(chatId: widget.chatId, text: text);
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(chatId: widget.chatId, chatName: widget.chatName),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;

                final memberRoles =
                    (data?['memberRoles'] as Map<String, dynamic>?) ?? {};

                return Stack(
                  children: [
                    MessagesList(
                      key: ValueKey(widget.chatId),
                      chatId: widget.chatId,
                      memberRoles: memberRoles,
                    ),
                    BannedOverlay(chatId: widget.chatId),
                  ],
                );
              },
            ),
          ),
          MessageInputArea(
            chatId: widget.chatId,
            controller: messageController,
            onSend: sendMessage,
          ),
        ],
      ),
    );
  }
}
