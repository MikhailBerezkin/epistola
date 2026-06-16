import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/chat_service.dart';
import '../widgets/chat_app_bar_title.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import 'group_info_screen.dart';

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
      appBar: _ChatAppBar(chatId: widget.chatId, chatName: widget.chatName),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _MessagesList(chatId: widget.chatId),
                _BannedOverlay(chatId: widget.chatId),
              ],
            ),
          ),
          _MessageInputArea(
            chatId: widget.chatId,
            controller: messageController,
            onSend: sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String chatId;
  final String chatName;

  const _ChatAppBar({required this.chatId, required this.chatName});

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

        final chatType = data?['type'] ?? 'private';
        final memberIds = (data?['memberIds'] as List?) ?? [];
        final isGroup = chatType == 'group';

        final subtitle = isGroup
            ? '${memberIds.length} участников'
            : 'личный чат';

        return AppBar(
          titleSpacing: 0,
          title: ChatAppBarTitle(chatName: chatName, subtitle: subtitle),
          actions: [
            if (isGroup)
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

class _MessagesList extends StatefulWidget {
  final String chatId;

  const _MessagesList({required this.chatId});

  @override
  State<_MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<_MessagesList> {
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
                data['senderName'] ?? data['senderEmail'] ?? 'Пользователь';
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
    );
  }
}

class _MessageInputArea extends StatelessWidget {
  final String chatId;
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInputArea({
    required this.chatId,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final chatService = ChatService();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;

        if (data == null) {
          return const SizedBox.shrink();
        }

        final chatType = data['type'] ?? 'private';
        final memberRoles =
            (data['memberRoles'] as Map<String, dynamic>?) ?? {};
        final memberStatus =
            (data['memberStatus'] as Map<String, dynamic>?) ?? {};
        final groupSettings =
            (data['groupSettings'] as Map<String, dynamic>?) ?? {};

        final isGroup = chatType == 'group';
        final currentUserRole = memberRoles[currentUser?.uid] ?? 'member';

        final statusData =
            (memberStatus[currentUser?.uid] as Map<String, dynamic>?) ??
            {'status': 'normal'};

        final status = statusData['status'] ?? 'normal';
        final statusIsActive = _isStatusActive(statusData);

        if (isGroup &&
            !statusIsActive &&
            status != 'normal' &&
            currentUser != null) {
          chatService.clearExpiredMemberStatus(
            chatId: chatId,
            userId: currentUser.uid,
          );
        }

        final isGuest = isGroup && currentUserRole == 'guest';
        final isMuted = isGroup && status == 'muted' && statusIsActive;
        final isBanned = isGroup && status == 'banned' && statusIsActive;

        final messagePermission = groupSettings['messagePermission'] ?? 'all';

        final canWriteByGroupPermission =
            !isGroup ||
            messagePermission == 'all' ||
            (messagePermission == 'moderators' &&
                (currentUserRole == 'moderator' ||
                    currentUserRole == 'admin' ||
                    currentUserRole == 'owner')) ||
            (messagePermission == 'admins' &&
                (currentUserRole == 'admin' || currentUserRole == 'owner'));

        final canSendMessages =
            !isGuest && !isMuted && !isBanned && canWriteByGroupPermission;

        if (canSendMessages) {
          return MessageInput(controller: controller, onSend: onSend);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              isGuest
                  ? 'Вы гость в этой группе и можете только читать сообщения'
                  : _formatStatusDetails(statusData),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BannedOverlay extends StatelessWidget {
  final String chatId;

  const _BannedOverlay({required this.chatId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;

        if (data == null || currentUser == null) {
          return const SizedBox.shrink();
        }

        final chatType = data['type'] ?? 'private';
        final memberStatus =
            (data['memberStatus'] as Map<String, dynamic>?) ?? {};
        final isGroup = chatType == 'group';

        final statusData =
            (memberStatus[currentUser.uid] as Map<String, dynamic>?) ??
            {'status': 'normal'};

        final status = statusData['status'] ?? 'normal';
        final isBanned =
            isGroup && status == 'banned' && _isStatusActive(statusData);

        if (!isBanned) {
          return const SizedBox.shrink();
        }

        final statusDetails = _formatStatusDetails(statusData);

        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Вы заблокированы в этой группе',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (statusDetails.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(statusDetails, textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Назад'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

bool _isStatusActive(Map<String, dynamic> statusData) {
  final permanent = statusData['permanent'] == true;
  final expiresAt = statusData['expiresAt'];

  if (permanent) return true;

  if (expiresAt is Timestamp) {
    return expiresAt.toDate().isAfter(DateTime.now());
  }

  return false;
}

String _formatStatusDetails(Map<String, dynamic> statusData) {
  final reason = statusData['reason'];
  final expiresAt = statusData['expiresAt'];
  final permanent = statusData['permanent'] == true;

  final parts = <String>[];

  if (reason != null && reason.toString().isNotEmpty) {
    parts.add('Причина: $reason');
  }

  if (permanent) {
    parts.add('Срок: навсегда');
  } else if (expiresAt is Timestamp) {
    final dateTime = expiresAt.toDate();
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    parts.add('До: $day.$month.$year $hour:$minute');
  }

  return parts.join('\n');
}
