import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../domain/value_objects/message_text.dart';
import '../domain/models/private_read_cursor.dart';
import '../models/app_user.dart';
import '../services/chat/active_chat_tracker.dart';
import '../services/chat/existing_image_message_send_service.dart';
import '../services/chat/private_read_cursor_mapper.dart';
import '../services/chat/private_read_receipt_debouncer.dart';
import '../services/chat/private_read_receipt_service.dart';
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

  late final ActiveChatRegistration _activeChatRegistration;
  late final PrivateReadReceiptService _privateReadReceiptService;
  late final PrivateReadReceiptDebouncer _privateReadReceiptDebouncer;

  String? lastNotifiedMessageId;

  bool isSendingImage = false;

  bool _allowPop = false;
  bool _isLeaving = false;
  bool _didScheduleFinalReadMark = false;

  @override
  void initState() {
    super.initState();
    _privateReadReceiptService = PrivateReadReceiptService.firebase();

    _privateReadReceiptDebouncer = PrivateReadReceiptDebouncer(
      commit: (cursor) async {
        await _privateReadReceiptService.markRead(
          chatId: widget.chatId,
          cursor: cursor,
        );
      },
      onError: (error, stackTrace) {
        debugPrint('Private read receipt write failed: $error');
      },
    );

    _activeChatRegistration = activeChatTracker.enter(widget.chatId);

    _markChatAsReadBestEffort();
    startIncomingMessageListener();
  }

  void _handleLatestReadCursorChanged(PrivateReadCursor cursor) {
    _privateReadReceiptDebouncer.schedule(cursor);
  }

  void _markChatAsReadBestEffort() {
    unawaited(
      chatService.markChatAsRead(widget.chatId).catchError((Object _) {
        // Firestore может поставить запись в локальную очередь.
        // Ошибка отметки прочтения не должна закрывать экран
        // и не должна мешать пользователю выйти из чата.
      }),
    );
  }

  void _scheduleFinalReadMark() {
    if (_didScheduleFinalReadMark) {
      return;
    }

    _didScheduleFinalReadMark = true;

    unawaited(_privateReadReceiptDebouncer.flushNow());

    _markChatAsReadBestEffort();
  }

  void _requestLeaveChat() {
    if (_isLeaving) {
      return;
    }

    _isLeaving = true;

    // Сначала запускаем обновление lastRead, чтобы локальный
    // Firestore snapshot успел попасть в список чатов.
    _scheduleFinalReadMark();

    setState(() {
      _allowPop = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    });
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
    // Fallback для случаев, когда route был удалён не обычной
    // кнопкой «Назад», а внешней навигационной операцией.
    _scheduleFinalReadMark();
    _privateReadReceiptDebouncer.dispose();

    activeChatTracker.leave(_activeChatRegistration);

    messagesSubscription?.cancel();
    messageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _requestLeaveChat();
      },
      child: Scaffold(
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
                  PrivateReadCursor? peerReadCursor;

                  if (chatType == 'private' && currentUserId != null) {
                    final clearedAtByUser =
                        (data['clearedAtByUser'] as Map<String, dynamic>?) ??
                        {};

                    final clearedAt = clearedAtByUser[currentUserId];

                    if (clearedAt is Timestamp) {
                      visibleAfter = clearedAt;
                    }

                    final memberIds = List<String>.from(
                      data['memberIds'] ?? const <String>[],
                    );

                    String? peerUserId;

                    for (final memberId in memberIds) {
                      if (memberId != currentUserId) {
                        peerUserId = memberId;
                        break;
                      }
                    }

                    if (peerUserId != null) {
                      peerReadCursor = PrivateReadCursorMapper.fromChatData(
                        chatData: data,
                        userId: peerUserId,
                      );
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
                        onLatestReadCursorChanged: chatType == 'private'
                            ? _handleLatestReadCursorChanged
                            : null,
                        peerReadCursor: peerReadCursor,
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
      ),
    );
  }
}
