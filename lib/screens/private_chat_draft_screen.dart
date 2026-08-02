import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../domain/value_objects/message_text.dart';
import '../models/app_user.dart';
import '../services/chat/first_private_image_message_send_service.dart';
import '../services/chat_service.dart';
import '../services/media/image_message_image_preparation_service.dart';
import '../services/media/image_message_image_processor.dart';
import '../widgets/chat_app_bar_title.dart';
import '../widgets/message_input.dart';
import 'chat_screen.dart';

class PrivateChatDraftScreen extends StatefulWidget {
  const PrivateChatDraftScreen({super.key, required this.otherUser});

  final AppUser otherUser;

  @override
  State<PrivateChatDraftScreen> createState() => _PrivateChatDraftScreenState();
}

class _PrivateChatDraftScreenState extends State<PrivateChatDraftScreen> {
  final messageController = TextEditingController();

  final chatService = ChatService();

  final imagePreparationService = ImageMessageImagePreparationService();

  final firstImageSendService = FirstPrivateImageMessageSendService();

  bool isSending = false;

  String get displayName {
    return widget.otherUser.name.isNotEmpty
        ? widget.otherUser.name
        : widget.otherUser.email;
  }

  Future<void> sendFirstMessage() async {
    if (isSending) {
      return;
    }

    final message = MessageText.tryParse(messageController.text);

    if (message == null) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      isSending = true;
    });

    try {
      final chatId = await chatService.createPrivateChatWithFirstMessage(
        otherUser: widget.otherUser,
        text: message.value,
      );

      if (!mounted) {
        return;
      }

      messageController.clear();

      _openCreatedChat(chatId);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать личный чат.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Future<void> sendFirstImageFromGallery() {
    return _sendFirstImage(imagePreparationService.prepareFromGallery);
  }

  Future<void> takeAndSendFirstPhoto() {
    return _sendFirstImage(imagePreparationService.prepareWithCamera);
  }

  Future<void> _sendFirstImage(
    Future<PreparedImageMessageImages?> Function() prepareImage,
  ) async {
    if (isSending) {
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
      isSending = true;
    });

    try {
      final preparedImages = await prepareImage();

      if (preparedImages == null) {
        return;
      }

      final result = await firstImageSendService.sendPreparedImage(
        preparedImages: preparedImages,
        uploaderId: currentUser.uid,
        otherUser: widget.otherUser,
      );

      if (!mounted) {
        return;
      }

      _openCreatedChat(result.chatId);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось создать личный чат '
            'с фотографией.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  void _openCreatedChat(String chatId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          return ChatScreen(
            chatId: chatId,
            chatName: displayName,
            peerUser: widget.otherUser,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ChatAppBarTitle(
          chatName: displayName,
          peerUser: widget.otherUser,
        ),
      ),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Напишите первое сообщение '
                  'или отправьте фотографию, '
                  'чтобы создать чат',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (isSending) const LinearProgressIndicator(),
          MessageInput(
            controller: messageController,
            onSend: sendFirstMessage,
            onPickFromGallery: sendFirstImageFromGallery,
            onTakePhoto: takeAndSendFirstPhoto,
            isBusy: isSending,
          ),
        ],
      ),
    );
  }
}
