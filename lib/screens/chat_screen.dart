import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/chat_service.dart';
import '../widgets/chat_app_bar_title.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import 'group_info_screen.dart';
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
      appBar: _ChatAppBar(chatId: widget.chatId, chatName: widget.chatName),
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
                    _MessagesList(
                      chatId: widget.chatId,
                      memberRoles: memberRoles,
                    ),
                    _BannedOverlay(chatId: widget.chatId),
                  ],
                );
              },
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
  final Map<String, dynamic> memberRoles;

  const _MessagesList({required this.chatId, required this.memberRoles});

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

class _MessageInputArea extends StatefulWidget {
  final String chatId;
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInputArea({
    required this.chatId,
    required this.controller,
    required this.onSend,
  });

  @override
  State<_MessageInputArea> createState() => _MessageInputAreaState();
}

class _MessageInputAreaState extends State<_MessageInputArea> {
  Timer? hideRestrictionTimer;
  bool showRestriction = true;

  @override
  void initState() {
    super.initState();

    hideRestrictionTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;

      setState(() {
        showRestriction = false;
      });
    });
  }

  @override
  void dispose() {
    hideRestrictionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final chatService = ChatService();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
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

        final canClearExpiredStatus =
            currentUserRole == 'admin' || currentUserRole == 'owner';

        if (isGroup &&
            canClearExpiredStatus &&
            !statusIsActive &&
            status != 'normal' &&
            currentUser != null) {
          chatService.clearExpiredMemberStatus(
            chatId: widget.chatId,
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
          return MessageInput(
            controller: widget.controller,
            onSend: widget.onSend,
          );
        }

        if (isBanned || !showRestriction) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _getRestrictionIcon(
                        isGuest: isGuest,
                        isMuted: isMuted,
                        isBanned: isBanned,
                        messagePermission: messagePermission,
                      ),
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getRestrictionTitle(
                              isGuest: isGuest,
                              isMuted: isMuted,
                              isBanned: isBanned,
                              messagePermission: messagePermission,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getRestrictionText(
                              isGuest: isGuest,
                              isMuted: isMuted,
                              isBanned: isBanned,
                              messagePermission: messagePermission,
                              statusData: statusData,
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

IconData _getRestrictionIcon({
  required bool isGuest,
  required bool isMuted,
  required bool isBanned,
  required String messagePermission,
}) {
  if (isBanned) return Icons.block;
  if (isMuted) return Icons.volume_off;
  if (isGuest) return Icons.visibility;
  return Icons.lock_outline;
}

String _getRestrictionTitle({
  required bool isGuest,
  required bool isMuted,
  required bool isBanned,
  required String messagePermission,
}) {
  if (isBanned) return 'Доступ к группе ограничен';
  if (isMuted) return 'Вы временно не можете писать';
  if (isGuest) return 'Режим гостя';

  if (messagePermission == 'admins') {
    return 'Писать могут только администраторы';
  }

  if (messagePermission == 'moderators') {
    return 'Писать могут модераторы и администраторы';
  }

  return 'Вы не можете отправлять сообщения';
}

String _getRestrictionText({
  required bool isGuest,
  required bool isMuted,
  required bool isBanned,
  required String messagePermission,
  required Map<String, dynamic> statusData,
}) {
  if (isGuest) {
    return 'Вы можете читать сообщения, но не можете отправлять свои.';
  }

  if (isMuted || isBanned) {
    final details = _formatStatusDetails(statusData);

    if (details.isEmpty) {
      return isMuted
          ? 'Модератор временно ограничил отправку сообщений.'
          : 'Администратор ограничил вам доступ к этой группе.';
    }

    return details;
  }

  if (messagePermission == 'admins') {
    return 'Эта группа находится в режиме ограниченной записи. Вы можете читать сообщения, но писать могут только администраторы.';
  }

  if (messagePermission == 'moderators') {
    return 'Эта группа находится в режиме ограниченной записи. Вы можете читать сообщения, но писать могут только модераторы и администраторы.';
  }

  return 'Отправка сообщений сейчас недоступна.';
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
