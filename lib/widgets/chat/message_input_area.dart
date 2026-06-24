import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import '../message_input.dart';

class MessageInputArea extends StatefulWidget {
  final String chatId;
  final TextEditingController controller;
  final VoidCallback onSend;

  const MessageInputArea({
    super.key,
    required this.chatId,
    required this.controller,
    required this.onSend,
  });

  @override
  State<MessageInputArea> createState() => _MessageInputAreaState();
}

class _MessageInputAreaState extends State<MessageInputArea> {
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
