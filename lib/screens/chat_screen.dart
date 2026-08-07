import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../domain/models/private_read_cursor.dart';
import '../domain/value_objects/message_text.dart';
import '../models/app_user.dart';
import '../services/chat/active_chat_tracker.dart';
import '../services/chat/chat_peer_resolver.dart';
import '../services/chat/existing_image_message_send_service.dart';
import '../services/chat/private_read_cursor_mapper.dart';
import '../services/chat/private_read_receipt_debouncer.dart';
import '../services/chat/private_read_receipt_service.dart';
import '../services/chat/private_typing_coordinator.dart';
import '../services/chat/private_typing_service.dart';
import '../services/chat_service.dart';
import '../services/media/image_message_image_preparation_service.dart';
import '../services/media/image_message_image_processor.dart';
import '../services/notification_service.dart';
import '../widgets/chat/banned_overlay.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_identity_overlay.dart';
import '../widgets/chat/chat_identity_background.dart';
import '../widgets/chat/chat_identity_card_content.dart';
import '../widgets/chat/message_input_area.dart';
import '../widgets/messages_list.dart';
import '../services/avatar/group_avatar_metadata_mapper.dart';
import 'group_info_screen.dart';
import '../widgets/chat/chat_identity_action_button.dart';
import '../domain/models/chat_notification_settings.dart';
import '../widgets/chat/chat_notification_settings_sheet.dart';

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
  State<ChatScreen> createState() {
    return _ChatScreenState();
  }
}

class _ChatScreenState extends State<ChatScreen> {
  static const _peerTypingFreshness = Duration(seconds: 6);
  final messageController = TextEditingController();

  final chatService = ChatService();

  final imagePreparationService = ImageMessageImagePreparationService();

  final imageSendService = ExistingImageMessageSendService();

  StreamSubscription<QuerySnapshot>? messagesSubscription;

  StreamSubscription<Object?>? _peerTypingSubscription;
  Timer? _peerTypingExpiryTimer;

  late final ActiveChatRegistration _activeChatRegistration;

  late final PrivateReadReceiptService _privateReadReceiptService;

  late final PrivateReadReceiptDebouncer _privateReadReceiptDebouncer;

  late final PrivateTypingService _privateTypingService;

  late final PrivateTypingCoordinator _privateTypingCoordinator;

  String? lastNotifiedMessageId;

  String? _typingPeerUserId;
  String? _scheduledTypingPeerUserId;

  Future<void>? _typingShutdownFuture;

  int _typingConfigurationRevision = 0;

  bool isSendingImage = false;

  bool _typingEnabled = false;
  bool _peerIsTyping = false;
  bool _isIdentityOverlayOpen = false;

  ChatNotificationSettings _currentNotificationSettings =
      const ChatNotificationSettings.sound();
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
        debugPrint(
          'Private read receipt write '
          'failed: $error',
        );
      },
    );

    _privateTypingService = PrivateTypingService.firebase();

    _privateTypingCoordinator = PrivateTypingCoordinator(
      startTyping: () async {
        await _privateTypingService.startTyping(chatId: widget.chatId);
      },
      stopTyping: () async {
        await _privateTypingService.stopTyping(chatId: widget.chatId);
      },
      onError: (error, stackTrace) {
        debugPrint(
          'Private typing operation '
          'failed: $error',
        );
      },
    );

    messageController.addListener(_handleMessageTextChanged);

    _activeChatRegistration = activeChatTracker.enter(widget.chatId);

    _markChatAsReadBestEffort();
    startIncomingMessageListener();
  }

  void _openIdentityOverlay() {
    if (_isIdentityOverlayOpen) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isIdentityOverlayOpen = true;
    });
  }

  void _closeIdentityOverlay() {
    if (!_isIdentityOverlayOpen) {
      return;
    }

    setState(() {
      _isIdentityOverlayOpen = false;
    });
  }

  void _handleLatestReadCursorChanged(PrivateReadCursor cursor) {
    _privateReadReceiptDebouncer.schedule(cursor);
  }

  void _handleMessageTextChanged() {
    if (!_typingEnabled) {
      return;
    }

    _privateTypingCoordinator.handleTextChanged(messageController.text);
  }

  void _markChatAsReadBestEffort() {
    unawaited(
      chatService.markChatAsRead(widget.chatId).catchError((Object _) {
        // Firestore может поставить запись
        // в локальную очередь.
        // Ошибка отметки прочтения не должна
        // закрывать экран или мешать выходу.
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

  Future<void> _requestLeaveChat() async {
    if (_isLeaving) {
      return;
    }

    _isLeaving = true;

    _scheduleFinalReadMark();

    try {
      await _shutdownPrivateTypingBestEffort().timeout(
        const Duration(seconds: 1),
      );
    } on TimeoutException {
      // Выход из экрана не должен зависеть
      // от скорости сети.
      // Незавершённая операция продолжит
      // выполняться, а onDisconnect остаётся
      // дополнительной страховкой.
    }

    if (!mounted) {
      return;
    }

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

          final notificationMode = _currentNotificationSettings.effectiveModeAt(
            DateTime.now(),
          );

          if (notificationMode != ChatNotificationMode.sound) {
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

    unawaited(_privateTypingCoordinator.stopNow());

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

      unawaited(_privateTypingCoordinator.stopNow());
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось отправить '
            'фотографию.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSendingImage = false;
        });
      }
    }
  }

  void _schedulePrivateTypingConfiguration(String? peerUserId) {
    final normalizedPeerUserId = peerUserId?.trim() ?? '';

    if (normalizedPeerUserId.isEmpty) {
      if (!_typingEnabled &&
          _typingPeerUserId == null &&
          _scheduledTypingPeerUserId == null) {
        return;
      }

      _scheduledTypingPeerUserId = null;

      final revision = ++_typingConfigurationRevision;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _typingConfigurationRevision) {
          return;
        }

        unawaited(_disablePrivateTyping(updateUi: true));
      });

      return;
    }

    if (_typingPeerUserId == normalizedPeerUserId ||
        _scheduledTypingPeerUserId == normalizedPeerUserId) {
      return;
    }

    _scheduledTypingPeerUserId = normalizedPeerUserId;

    final revision = ++_typingConfigurationRevision;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _typingConfigurationRevision) {
        return;
      }

      unawaited(
        _configurePrivateTyping(
          peerUserId: normalizedPeerUserId,
          revision: revision,
        ),
      );
    });
  }

  Future<void> _configurePrivateTyping({
    required String peerUserId,
    required int revision,
  }) async {
    try {
      await _privateTypingService.prepare(chatId: widget.chatId);

      if (!mounted || revision != _typingConfigurationRevision) {
        return;
      }

      await _peerTypingSubscription?.cancel();

      final subscription = _privateTypingService
          .watchPeerState(chatId: widget.chatId, peerUserId: peerUserId)
          .listen(
            (value) {
              _handlePeerTypingValue(value, revision: revision);
            },
            onError: (Object error) {
              debugPrint(
                'Private typing listener '
                'failed: $error',
              );

              _updatePeerTyping(false);
            },
            onDone: () {
              _updatePeerTyping(false);
            },
          );

      if (!mounted || revision != _typingConfigurationRevision) {
        await subscription.cancel();
        return;
      }

      _peerTypingSubscription = subscription;

      _typingPeerUserId = peerUserId;
      _typingEnabled = true;

      final currentText = messageController.text;

      if (currentText.isNotEmpty) {
        _privateTypingCoordinator.handleTextChanged(currentText);
      }
    } catch (error) {
      debugPrint(
        'Private typing setup failed: '
        '$error',
      );

      if (revision == _typingConfigurationRevision) {
        _typingEnabled = false;
        _typingPeerUserId = null;

        _updatePeerTyping(false);
      }
    } finally {
      if (_scheduledTypingPeerUserId == peerUserId) {
        _scheduledTypingPeerUserId = null;
      }
    }
  }

  void _handlePeerTypingValue(Object? value, {required int revision}) {
    if (revision != _typingConfigurationRevision) {
      return;
    }

    _peerTypingExpiryTimer?.cancel();
    _peerTypingExpiryTimer = null;

    if (value is! num || value <= 0) {
      _updatePeerTyping(false);
      return;
    }

    final timestampMilliseconds = value.toInt();

    final nowMilliseconds = DateTime.now().millisecondsSinceEpoch;

    final ageMilliseconds = nowMilliseconds - timestampMilliseconds;

    const futureToleranceMilliseconds = 10000;

    final freshnessMilliseconds = _peerTypingFreshness.inMilliseconds;

    if (ageMilliseconds < -futureToleranceMilliseconds ||
        ageMilliseconds >= freshnessMilliseconds) {
      _updatePeerTyping(false);
      return;
    }

    final effectiveAgeMilliseconds = ageMilliseconds < 0 ? 0 : ageMilliseconds;

    final remainingMilliseconds =
        freshnessMilliseconds - effectiveAgeMilliseconds;

    _updatePeerTyping(true);

    _peerTypingExpiryTimer = Timer(
      Duration(milliseconds: remainingMilliseconds),
      () {
        _peerTypingExpiryTimer = null;

        if (revision != _typingConfigurationRevision) {
          return;
        }

        _updatePeerTyping(false);
      },
    );
  }

  void _updatePeerTyping(bool isTyping) {
    if (!mounted || _peerIsTyping == isTyping) {
      return;
    }

    setState(() {
      _peerIsTyping = isTyping;
    });
  }

  Future<void> _disablePrivateTyping({required bool updateUi}) async {
    _peerTypingExpiryTimer?.cancel();
    _peerTypingExpiryTimer = null;
    _typingEnabled = false;
    _typingPeerUserId = null;

    final subscription = _peerTypingSubscription;

    _peerTypingSubscription = null;

    await subscription?.cancel();

    try {
      await _privateTypingCoordinator.stopNow();
    } catch (error) {
      debugPrint(
        'Private typing stop failed: '
        '$error',
      );
    }

    try {
      await _privateTypingService.close(chatId: widget.chatId);
    } catch (error) {
      debugPrint(
        'Private typing close failed: '
        '$error',
      );
    }

    if (updateUi) {
      _updatePeerTyping(false);
    } else {
      _peerIsTyping = false;
    }
  }

  Future<void> _shutdownPrivateTypingBestEffort() {
    final existingFuture = _typingShutdownFuture;

    if (existingFuture != null) {
      return existingFuture;
    }

    _typingConfigurationRevision += 1;
    _scheduledTypingPeerUserId = null;

    final shutdownFuture = _disablePrivateTyping(updateUi: false);

    _typingShutdownFuture = shutdownFuture;

    return shutdownFuture;
  }

  @override
  void dispose() {
    messageController.removeListener(_handleMessageTextChanged);

    _scheduleFinalReadMark();

    unawaited(_shutdownPrivateTypingBestEffort());

    _privateTypingCoordinator.dispose();

    _privateReadReceiptDebouncer.dispose();

    activeChatTracker.leave(_activeChatRegistration);

    messagesSubscription?.cancel();

    messageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    String groupMemberCountLabel(int count) {
      final mod10 = count % 10;
      final mod100 = count % 100;

      if (mod10 == 1 && mod100 != 11) {
        return '$count участник';
      }

      if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
        return '$count участника';
      }

      return '$count участников';
    }

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (_isIdentityOverlayOpen) {
          _closeIdentityOverlay();
          return;
        }

        unawaited(_requestLeaveChat());
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;

          final chatType = data?['type'] ?? 'private';
          final isGroup = chatType == 'group';

          final memberIds = List<String>.from(
            data?['memberIds'] ?? const <String>[],
          );

          final memberRoles =
              (data?['memberRoles'] as Map<String, dynamic>?) ??
              <String, dynamic>{};

          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          final currentUserRole = currentUserId == null
              ? 'member'
              : (memberRoles[currentUserId] ?? 'member').toString();

          final canManageGroup =
              isGroup &&
              (currentUserRole == 'admin' || currentUserRole == 'owner');

          final peerUserId =
              data != null && currentUserId != null && chatType == 'private'
              ? ChatPeerResolver.otherUserId(
                  chatData: data,
                  currentUserId: currentUserId,
                )
              : null;

          _schedulePrivateTypingConfiguration(peerUserId);

          Timestamp? visibleAfter;
          PrivateReadCursor? peerReadCursor;

          if (data != null && chatType == 'private' && currentUserId != null) {
            final clearedAtByUser =
                (data['clearedAtByUser'] as Map<String, dynamic>?) ??
                <String, dynamic>{};

            final clearedAt = clearedAtByUser[currentUserId];

            if (clearedAt is Timestamp) {
              visibleAfter = clearedAt;
            }

            if (peerUserId != null) {
              peerReadCursor = PrivateReadCursorMapper.fromChatData(
                chatData: data,
                userId: peerUserId,
              );
            }
          }

          final groupNameFromData = data?['name']?.toString().trim() ?? '';

          final groupName = groupNameFromData.isNotEmpty
              ? groupNameFromData
              : widget.chatName.trim();

          final groupAvatar = isGroup && data != null
              ? GroupAvatarMetadataMapper.fromMap(
                  data: data,
                  chatId: widget.chatId,
                )
              : null;

          final identityUser = isGroup ? null : widget.peerUser;

          final identityAvatar = identityUser?.effectiveAvatar;

          final normalizedIdentityName = identityUser?.name.trim() ?? '';

          final privateIdentityName = normalizedIdentityName.isNotEmpty
              ? normalizedIdentityName
              : widget.chatName.trim();

          final identityName = isGroup ? groupName : privateIdentityName;

          final normalizedIdentityUserId = identityUser?.uid.trim() ?? '';

          final identityStableKey = isGroup
              ? widget.chatId
              : normalizedIdentityUserId.isNotEmpty
              ? normalizedIdentityUserId
              : widget.chatId;

          final identityStoragePath = isGroup
              ? groupAvatar?.fullStoragePath
              : identityAvatar?.fullStoragePath;

          final identityVersion = isGroup
              ? groupAvatar?.version
              : identityAvatar?.version;

          final identityImageUrl = isGroup
              ? groupAvatar?.fullUrl
              : identityUser?.effectiveAvatarFullUrl;

          final identityCacheKey = isGroup
              ? groupAvatar?.fullCacheKey(widget.chatId)
              : identityAvatar?.fullCacheKey(
                  normalizedIdentityUserId.isNotEmpty
                      ? normalizedIdentityUserId
                      : widget.chatId,
                );

          final identityDetails = isGroup
              ? <String>[groupMemberCountLabel(memberIds.length)]
              : <String>[identityUser?.about ?? '', identityUser?.phone ?? ''];

          final notificationSettings = data == null || currentUserId == null
              ? const ChatNotificationSettings.sound()
              : ChatNotificationSettings.fromChatData(
                  chatData: data,
                  userId: currentUserId,
                );
          _currentNotificationSettings = notificationSettings;

          final effectiveNotificationMode = notificationSettings
              .effectiveModeAt(DateTime.now());

          late final IconData notificationButtonIcon;
          late final String notificationButtonLabel;

          switch (effectiveNotificationMode) {
            case ChatNotificationMode.sound:
              notificationButtonIcon = Icons.notifications_none;
              notificationButtonLabel = 'Уведомления';

            case ChatNotificationMode.silent:
              notificationButtonIcon = Icons.notifications_off_outlined;
              notificationButtonLabel = 'Без звука';

            case ChatNotificationMode.disabled:
              notificationButtonIcon = Icons.notifications_off_outlined;
              notificationButtonLabel = 'Отключены';
          }

          final identityActions = <Widget>[
            ChatIdentityActionButton(
              icon: notificationButtonIcon,
              label: notificationButtonLabel,
              onTap: () {
                showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (sheetContext) {
                    return ChatNotificationSettingsSheet(
                      chatId: widget.chatId,
                      initialSettings: notificationSettings,
                    );
                  },
                );
              },
            ),
            if (isGroup)
              ChatIdentityActionButton(
                icon: Icons.group_outlined,
                label: 'Участники',
                onTap: () {
                  _closeIdentityOverlay();

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupInfoScreen(
                        chatId: widget.chatId,
                        membersOnly: true,
                      ),
                    ),
                  );
                },
              ),
            if (canManageGroup)
              ChatIdentityActionButton(
                icon: Icons.settings_outlined,
                label: 'Управление',
                onTap: () {
                  _closeIdentityOverlay();

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupInfoScreen(chatId: widget.chatId),
                    ),
                  );
                },
              ),
          ];

          return Stack(
            children: [
              Scaffold(
                appBar: ChatAppBar(
                  chatId: widget.chatId,
                  chatName: widget.chatName,
                  peerUser: widget.peerUser,
                  peerIsTyping: _peerIsTyping,
                  chatData: data,
                  onIdentityTap: _openIdentityOverlay,
                ),
                body: Column(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              data == null) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (data == null) {
                            return const Center(child: Text('Чат недоступен'));
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
                                enableGroupReactions: chatType == 'group',
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
              ChatIdentityOverlay(
                isOpen: _isIdentityOverlayOpen,
                onClose: _closeIdentityOverlay,
                child: ChatIdentityBackground(
                  stableKey: identityStableKey,
                  name: identityName,
                  email: identityUser?.email ?? '',
                  storagePath: identityStoragePath,
                  version: identityVersion,
                  imageUrl: identityImageUrl,
                  cacheKey: identityCacheKey,
                  child: ChatIdentityCardContent(
                    title: identityName.isEmpty
                        ? 'Информация о чате'
                        : identityName,
                    details: identityDetails,
                    actions: identityActions,
                    onClose: _closeIdentityOverlay,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
