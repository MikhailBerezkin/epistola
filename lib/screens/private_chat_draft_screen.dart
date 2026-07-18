import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../domain/value_objects/message_text.dart';
import '../models/app_user.dart';
import '../services/chat_service.dart';
import '../widgets/message_input.dart';
import 'chat_screen.dart';

class PrivateChatDraftScreen extends StatefulWidget {
  final AppUser otherUser;

  const PrivateChatDraftScreen({super.key, required this.otherUser});

  @override
  State<PrivateChatDraftScreen> createState() => _PrivateChatDraftScreenState();
}

class _PrivateChatDraftScreenState extends State<PrivateChatDraftScreen> {
  final messageController = TextEditingController();
  final chatService = ChatService();

  bool isSending = false;

  String get displayName {
    return widget.otherUser.name.isNotEmpty
        ? widget.otherUser.name
        : widget.otherUser.email;
  }

  Future<void> sendFirstMessage() async {
    if (isSending) return;

    final message = MessageText.tryParse(messageController.text);

    if (message == null) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() => isSending = true);

    try {
      final chatId = await chatService.createPrivateChatWithFirstMessage(
        otherUser: widget.otherUser,
        text: message.value,
      );

      if (!mounted) return;

      messageController.clear();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, chatName: displayName),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать личный чат')),
      );
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName),
            Text(
              'личный чат',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Напишите первое сообщение, чтобы создать чат',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (isSending) const LinearProgressIndicator(),
          AbsorbPointer(
            absorbing: isSending,
            child: MessageInput(
              controller: messageController,
              onSend: sendFirstMessage,
            ),
          ),
        ],
      ),
    );
  }
}
