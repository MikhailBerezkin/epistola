import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../domain/value_objects/message_text.dart';
import '../models/app_user.dart';
import '../services/chat/existing_image_message_send_service.dart';
import '../services/chat_service.dart';
import '../services/media/image_message_image_preparation_service.dart';
import '../services/media/image_message_image_processor.dart';
import '../services/notification_service.dart';
import '../widgets/chat/banned_overlay.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/message_input_area.dart';
import '../widgets/messages_list.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.peerUser,
  });

  final String chatId;
  final String chatName;
  final AppUser? peerUser;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageController = TextEditingController();

  final chatService = ChatService();

  final imagePreparationService = ImageMessageImagePreparationService();

  final imageSendService = ExistingImageMessageSendService();

  StreamSubscription<QuerySnapshot>? messagesSubscription;

  String? lastNotifiedMessageId;

  bool isSendingImage = false;

  @override
  void initState() {
    super.initState();

    chatService.markChatAsRead(widget.chatId);
    startIncomingMessageListener();
  }

  void startIncomingMessageListener() {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    messagesSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.docs.isEmpty) {
            return;
          }

          final latestMessage = snapshot.docs.first;

          final data = latestMessage.data();

          final messageId = latestMessage.id;
          final senderId = data['senderId'];

          if (lastNotifiedMessageId == null) {
            lastNotifiedMessageId = messageId;
            return;
          }

          if (messageId == lastNotifiedMessageId) {
            return;
          }

          lastNotifiedMessageId = messageId;

          if (senderId == currentUser.uid) {
            return;
          }

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
            content: Text(
              'Сообщение не может быть '
              'длиннее 4096 символов.',
            ),
          ),
        );
      }

      return;
    }

    HapticFeedback.selectionClick();

    messageController.clear();

    await chatService.sendMessage(chatId: widget.chatId, text: message.value);
  }

  Future<void> sendImageFromGallery() {
    return _sendImage(imagePreparationService.prepareFromGallery);
  }

  Future<void> takeAndSendPhoto() {
    return _sendImage(imagePreparationService.prepareWithCamera);
  }

  Future<void> _sendImage(
    Future<PreparedImageMessageImages?> Function() prepareImage,
  ) async {
    if (isSendingImage) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Для отправки фотографии '
            'нужно войти в аккаунт.',
          ),
        ),
      );

      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      isSendingImage = true;
    });

    try {
      final preparedImages = await prepareImage();

      if (preparedImages == null) {
        return;
      }

      await imageSendService.sendPreparedImage(
        preparedImages: preparedImages,
        uploaderId: currentUser.uid,
        chatId: widget.chatId,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить фотографию.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSendingImage = false;
        });
      }
    }
  }

  @override
  void dispose() {
    messagesSubscription?.cancel();
    messageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: ChatAppBar(
        chatId: widget.chatId,
        chatName: widget.chatName,
        peerUser: widget.peerUser,
      ),
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
                      keyboardInset: keyboardInset,
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
            onPickFromGallery: sendImageFromGallery,
            onTakePhoto: takeAndSendPhoto,
            isBusy: isSendingImage,
          ),
        ],
      ),
    );
  }
}
