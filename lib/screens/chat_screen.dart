import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../services/chat_service.dart';
import '../widgets/messages_list.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/message_input_area.dart';
import '../widgets/chat/banned_overlay.dart';

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../domain/value_objects/message_text.dart';

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
  StreamSubscription<QuerySnapshot>? messagesSubscription;
  String? lastNotifiedMessageId;

  @override
  void initState() {
    super.initState();
    chatService.markChatAsRead(widget.chatId);
    startIncomingMessageListener();
  }

  void startIncomingMessageListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    messagesSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.docs.isEmpty) return;

          final latestMessage = snapshot.docs.first;
          final data = latestMessage.data();

          final messageId = latestMessage.id;
          final senderId = data['senderId'];

          if (lastNotifiedMessageId == null) {
            lastNotifiedMessageId = messageId;
            return;
          }

          if (messageId == lastNotifiedMessageId) return;

          lastNotifiedMessageId = messageId;

          if (senderId == currentUser.uid) return;

          await NotificationService.vibrate();
        });
  }

  Future<void> sendMessage() async {
    final message = MessageText.tryParse(messageController.text);

    if (message == null) {
      final normalized = MessageText.normalize(messageController.text);

      if (normalized.length > MessageText.maxLength && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сообщение не может быть длиннее 4096 символов.'),
          ),
        );
      }

      return;
    }

    HapticFeedback.selectionClick();
    messageController.clear();

    await chatService.sendMessage(chatId: widget.chatId, text: message.value);
  }

  @override
  void dispose() {
    messagesSubscription?.cancel();
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

                if (snapshot.connectionState == ConnectionState.waiting &&
                    data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (data == null) {
                  return const Center(child: Text('Чат недоступен'));
                }

                final memberRoles =
                    (data['memberRoles'] as Map<String, dynamic>?) ?? {};

                final currentUserId = FirebaseAuth.instance.currentUser?.uid;

                final chatType = data['type'] ?? 'group';

                Timestamp? visibleAfter;

                if (chatType == 'private' && currentUserId != null) {
                  final clearedAtByUser =
                      (data['clearedAtByUser'] as Map<String, dynamic>?) ?? {};

                  final clearedAt = clearedAtByUser[currentUserId];

                  if (clearedAt is Timestamp) {
                    visibleAfter = clearedAt;
                  }
                }

                return Stack(
                  children: [
                    MessagesList(
                      key: ValueKey(
                        '${widget.chatId}_'
                        '${visibleAfter?.toDate().millisecondsSinceEpoch ?? 0}',
                      ),
                      chatId: widget.chatId,
                      memberRoles: memberRoles,
                      visibleAfter: visibleAfter,
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
