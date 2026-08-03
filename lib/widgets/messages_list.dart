import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../helpers/chat_date_formatter.dart';
import '../models/message_presentation.dart';
import '../services/chat/image_message_metadata_mapper.dart';
import '../services/chat_service.dart';
import 'chat/chat_scroll_date_indicator.dart';
import 'message_item.dart';

enum _MessageDeleteAction { forCurrentUser, forEveryone }

class MessagesList extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> memberRoles;
  final Timestamp? visibleAfter;
  final double keyboardInset;

  const MessagesList({
    super.key,
    required this.chatId,
    required this.memberRoles,
    required this.keyboardInset,
    this.visibleAfter,
  });

  @override
  State<MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<MessagesList> {
  static const int _pageSize = 20;
  static const double _loadMoreThreshold = 240;
  static const double _scrollDateProbeOffset = 48;

  static const Duration _scrollDateHideDelay = Duration(milliseconds: 1200);

  final chatService = ChatService();
  final scrollController = ScrollController();

  final GlobalKey _messagesViewportKey = GlobalKey();

  final Map<String, GlobalKey> _messageItemKeys = {};
  final Set<String> _locallyHiddenMessageIds = <String>{};

  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _messagesById =
      {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _latestMessagesSubscription;

  Timer? _bottomCorrectionTimer;
  Timer? _scrollDateHideTimer;

  QueryDocumentSnapshot<Map<String, dynamic>>? _oldestLoadedDocument;

  bool _isInitialLoading = true;
  bool _isLoadingOlder = false;
  bool _hasMore = true;
  bool _hasRequestedOlderPage = false;

  bool _isUserScrolling = false;
  bool _isScrollDateVisible = false;
  bool _scrollDateUpdateScheduled = false;

  String? _scrollDateLabel;

  Object? _initialLoadError;

  @override
  void initState() {
    super.initState();

    scrollController.addListener(_handleScroll);
    _subscribeToLatestMessages();
  }

  @override
  void didUpdateWidget(covariant MessagesList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final conversationChanged =
        oldWidget.chatId != widget.chatId ||
        oldWidget.visibleAfter != widget.visibleAfter;

    if (conversationChanged) {
      unawaited(_restartSubscription());
      return;
    }

    final keyboardInsetChanged =
        (oldWidget.keyboardInset - widget.keyboardInset).abs() > 0.5;

    if (keyboardInsetChanged && _isNearBottom) {
      _scrollToBottom(animated: false, correctAfterLayout: true);
    }
  }

  Future<void> _restartSubscription() async {
    await _latestMessagesSubscription?.cancel();

    if (!mounted) {
      return;
    }

    _scrollDateHideTimer?.cancel();
    _messageItemKeys.clear();
    _locallyHiddenMessageIds.clear();

    setState(() {
      _messagesById.clear();
      _oldestLoadedDocument = null;

      _isInitialLoading = true;
      _isLoadingOlder = false;
      _hasMore = true;
      _hasRequestedOlderPage = false;

      _isUserScrolling = false;
      _isScrollDateVisible = false;
      _scrollDateLabel = null;

      _initialLoadError = null;
    });

    _subscribeToLatestMessages();
  }

  void _subscribeToLatestMessages() {
    _latestMessagesSubscription = chatService
        .watchLatestMessages(
          widget.chatId,
          after: widget.visibleAfter,
          pageSize: _pageSize,
        )
        .listen(
          _handleLatestSnapshot,
          onError: (Object error) {
            if (!mounted) {
              return;
            }

            setState(() {
              _isInitialLoading = false;
              _initialLoadError = error;
            });
          },
        );
  }

  void _handleLatestSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) {
      return;
    }

    final wasInitialLoad = _isInitialLoading && _messagesById.isEmpty;
    final wasNearBottom = _isNearBottom;
    final previousIds = _messagesById.keys.toSet();

    for (final message in snapshot.docs) {
      _messagesById[message.id] = message;
    }

    final addedMessage = snapshot.docs.any(
      (message) => !previousIds.contains(message.id),
    );

    _updateOldestLoadedDocument();

    setState(() {
      _isInitialLoading = false;
      _initialLoadError = null;

      if (!_hasRequestedOlderPage) {
        _hasMore = snapshot.docs.length == _pageSize;
      }
    });

    if (wasInitialLoad) {
      _scrollToBottom(animated: false, correctAfterLayout: true);
    } else if (addedMessage && wasNearBottom) {
      _scrollToBottom(correctAfterLayout: true);
    }

    if (_isUserScrolling) {
      _scheduleScrollDateUpdate();
    }
  }

  void _handleScroll() {
    if (!scrollController.hasClients) {
      return;
    }

    if (scrollController.position.pixels <= _loadMoreThreshold) {
      unawaited(_loadOlderMessages());
    }

    if (_isUserScrolling) {
      _scheduleScrollDateUpdate();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final axis = axisDirectionToAxis(notification.metrics.axisDirection);

    if (axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isUserScrolling = true;
        _showScrollDateIndicator();
      } else if (_isUserScrolling) {
        _showScrollDateIndicator();
      }

      return false;
    }

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      if (_isUserScrolling) {
        _showScrollDateIndicator();
      }

      return false;
    }

    if (notification is ScrollEndNotification && _isUserScrolling) {
      _isUserScrolling = false;

      _scheduleScrollDateUpdate();
      _scheduleScrollDateHide();
    }

    return false;
  }

  void _showScrollDateIndicator() {
    _scrollDateHideTimer?.cancel();

    if (!_isScrollDateVisible && mounted) {
      setState(() {
        _isScrollDateVisible = true;
      });
    }

    _scheduleScrollDateUpdate();
  }

  void _scheduleScrollDateHide() {
    _scrollDateHideTimer?.cancel();

    _scrollDateHideTimer = Timer(_scrollDateHideDelay, () {
      if (!mounted || _isUserScrolling) {
        return;
      }

      setState(() {
        _isScrollDateVisible = false;
      });
    });
  }

  void _scheduleScrollDateUpdate() {
    if (_scrollDateUpdateScheduled) {
      return;
    }

    _scrollDateUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollDateUpdateScheduled = false;

      if (!mounted) {
        return;
      }

      _updateScrollDateLabel();
    });
  }

  void _updateScrollDateLabel() {
    final viewportContext = _messagesViewportKey.currentContext;
    final viewportRenderObject = viewportContext?.findRenderObject();

    if (viewportRenderObject is! RenderBox || !viewportRenderObject.attached) {
      return;
    }

    final viewportTop =
        viewportRenderObject.localToGlobal(Offset.zero).dy +
        _scrollDateProbeOffset;

    final viewportBottom = viewportRenderObject
        .localToGlobal(Offset(0, viewportRenderObject.size.height))
        .dy;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    String? nextLabel;

    for (final message in _sortedMessages) {
      final data = message.data();

      if (!_isMessageVisibleForCurrentUser(
        messageId: message.id,
        data: data,
        currentUserId: currentUserId,
      )) {
        continue;
      }

      final messageKey = _messageItemKeys[message.id];
      final messageContext = messageKey?.currentContext;
      final messageRenderObject = messageContext?.findRenderObject();

      if (messageRenderObject is! RenderBox ||
          !messageRenderObject.attached ||
          messageRenderObject.size.height <= 0) {
        continue;
      }

      final messageTop = messageRenderObject.localToGlobal(Offset.zero).dy;

      final messageBottom = messageTop + messageRenderObject.size.height;

      final crossesProbeLine =
          messageBottom > viewportTop && messageTop < viewportBottom;

      if (!crossesProbeLine) {
        continue;
      }

      final createdAt = data['createdAt'];

      if (createdAt is Timestamp) {
        nextLabel = ChatDateFormatter.format(createdAt.toDate());
      }

      break;
    }

    if (nextLabel == null || nextLabel == _scrollDateLabel) {
      return;
    }

    setState(() {
      _scrollDateLabel = nextLabel;
    });
  }

  Future<void> _loadOlderMessages() async {
    final oldestDocument = _oldestLoadedDocument;

    if (_isInitialLoading ||
        _isLoadingOlder ||
        !_hasMore ||
        oldestDocument == null) {
      return;
    }

    final previousMaxScrollExtent = scrollController.position.maxScrollExtent;

    final previousPixels = scrollController.position.pixels;

    setState(() {
      _isLoadingOlder = true;
      _hasRequestedOlderPage = true;
    });

    try {
      final snapshot = await chatService.loadOlderMessages(
        widget.chatId,
        before: oldestDocument,
        after: widget.visibleAfter,
        pageSize: _pageSize,
      );

      if (!mounted) {
        return;
      }

      for (final message in snapshot.docs) {
        _messagesById[message.id] = message;
      }

      _updateOldestLoadedDocument();

      setState(() {
        _isLoadingOlder = false;
        _hasMore = snapshot.docs.length == _pageSize;
      });

      if (snapshot.docs.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!scrollController.hasClients) {
            return;
          }

          final newMaxScrollExtent = scrollController.position.maxScrollExtent;

          final addedExtent = newMaxScrollExtent - previousMaxScrollExtent;

          scrollController.jumpTo(previousPixels + addedExtent);

          if (_isUserScrolling) {
            _scheduleScrollDateUpdate();
          }
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingOlder = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось загрузить предыдущие сообщения.'),
        ),
      );
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _sortedMessages {
    final messages = _messagesById.values.toList();

    messages.sort(_compareMessages);

    return messages;
  }

  int _compareMessages(
    QueryDocumentSnapshot<Map<String, dynamic>> first,
    QueryDocumentSnapshot<Map<String, dynamic>> second,
  ) {
    final firstTimestamp = first.data()['createdAt'];
    final secondTimestamp = second.data()['createdAt'];

    if (firstTimestamp is Timestamp && secondTimestamp is Timestamp) {
      final timestampComparison = firstTimestamp.compareTo(secondTimestamp);

      if (timestampComparison != 0) {
        return timestampComparison;
      }
    } else if (firstTimestamp is Timestamp) {
      return -1;
    } else if (secondTimestamp is Timestamp) {
      return 1;
    }

    return first.id.compareTo(second.id);
  }

  bool _isMessageVisibleForCurrentUser({
    required String messageId,
    required Map<String, dynamic> data,
    required String? currentUserId,
  }) {
    if (_locallyHiddenMessageIds.contains(messageId)) {
      return false;
    }

    if (data['deletedForEveryone'] == true) {
      return false;
    }

    final hiddenFor = data['hiddenFor'];

    final isHiddenForCurrentUser =
        currentUserId != null &&
        hiddenFor is Map<String, dynamic> &&
        hiddenFor[currentUserId] is Timestamp;

    return !isHiddenForCurrentUser;
  }

  Map<String, String> _buildDateLabels({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
    required String? currentUserId,
  }) {
    final labels = <String, String>{};

    DateTime? previousVisibleMessageDate;

    for (final message in messages) {
      final data = message.data();

      if (!_isMessageVisibleForCurrentUser(
        messageId: message.id,
        data: data,
        currentUserId: currentUserId,
      )) {
        continue;
      }

      final createdAt = data['createdAt'];

      if (createdAt is! Timestamp) {
        continue;
      }

      final messageDate = createdAt.toDate();

      final startsNewDay = ChatDateFormatter.startsNewDay(
        current: messageDate,
        previous: previousVisibleMessageDate,
      );

      if (startsNewDay) {
        labels[message.id] = ChatDateFormatter.format(messageDate);
      }

      previousVisibleMessageDate = messageDate;
    }

    return labels;
  }

  GlobalKey _messageItemKey(String messageId) {
    return _messageItemKeys.putIfAbsent(
      messageId,
      () => GlobalKey(debugLabel: 'chat-message-$messageId'),
    );
  }

  void _updateOldestLoadedDocument() {
    final messages = _sortedMessages;

    _oldestLoadedDocument = messages.isEmpty ? null : messages.first;
  }

  bool get _isNearBottom {
    if (!scrollController.hasClients) {
      return true;
    }

    final position = scrollController.position;

    return position.maxScrollExtent - position.pixels < 180;
  }

  void _hideMessageLocally(String messageId) {
    if (!mounted || _locallyHiddenMessageIds.contains(messageId)) {
      return;
    }

    setState(() {
      _locallyHiddenMessageIds.add(messageId);
    });

    _scheduleScrollDateUpdate();
  }

  Future<void> _showMessageActions({
    required MessagePresentation message,
    required bool isMe,
  }) async {
    if (!message.isVisible) {
      return;
    }

    final action = await showModalBottomSheet<_MessageDeleteAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Удалить у себя'),
                onTap: () {
                  Navigator.of(
                    sheetContext,
                  ).pop(_MessageDeleteAction.forCurrentUser);
                },
              ),
              if (isMe)
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                  title: Text(
                    'Удалить у всех',
                    style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop(_MessageDeleteAction.forEveryone);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _MessageDeleteAction.forEveryone) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Удалить у всех?'),
            content: const Text('Сообщение исчезнет у всех участников чата.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Отмена'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Удалить'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmed != true) {
        return;
      }
    }

    try {
      switch (action) {
        case _MessageDeleteAction.forCurrentUser:
          await chatService.deleteMessageForCurrentUser(
            chatId: widget.chatId,
            messageId: message.id,
          );

          _hideMessageLocally(message.id);
          return;

        case _MessageDeleteAction.forEveryone:
          await chatService.deleteMessageForEveryone(
            chatId: widget.chatId,
            messageId: message.id,
          );

          _hideMessageLocally(message.id);
          return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить сообщение.')),
      );
    }
  }

  String formatMessageTime(dynamic createdAt) {
    if (createdAt == null || createdAt is! Timestamp) {
      return '';
    }

    final dateTime = createdAt.toDate();

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void _scrollToBottom({
    bool animated = true,
    bool correctAfterLayout = false,
  }) {
    _bottomCorrectionTimer?.cancel();

    void performScroll({required bool useAnimation}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scrollController.hasClients) {
          return;
        }

        final position = scrollController.position;
        final bottom = position.maxScrollExtent;
        final distance = bottom - position.pixels;

        if (distance.abs() < 1) {
          return;
        }

        if (useAnimation) {
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

    performScroll(useAnimation: animated);

    if (!correctAfterLayout) {
      return;
    }

    _bottomCorrectionTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }

      performScroll(useAnimation: true);
    });
  }

  @override
  void dispose() {
    _latestMessagesSubscription?.cancel();
    _bottomCorrectionTimer?.cancel();
    _scrollDateHideTimer?.cancel();

    scrollController.removeListener(_handleScroll);
    scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final messages = _sortedMessages;

    final dateLabelsByMessageId = _buildDateLabels(
      messages: messages,
      currentUserId: currentUser?.uid,
    );

    if (_isInitialLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_initialLoadError != null && messages.isEmpty) {
      return const Center(child: Text('Не удалось загрузить сообщения'));
    }

    if (messages.isEmpty) {
      return const Center(child: Text('Сообщений пока нет'));
    }

    final shouldOffsetLoadingIndicator =
        _isScrollDateVisible && _scrollDateLabel != null;

    return Stack(
      children: [
        Positioned.fill(
          child: SizedBox(
            key: _messagesViewportKey,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final data = message.data();

                  final text = data['text'] is String
                      ? data['text'] as String
                      : '';

                  final messageType = data['messageType'] is String
                      ? data['messageType'] as String
                      : 'text';

                  final imageData = data['image'];

                  final imageMetadata =
                      messageType == 'image' &&
                          imageData is Map<String, dynamic>
                      ? ImageMessageMetadataMapper.fromMap(
                          data: imageData,
                          chatId: widget.chatId,
                          messageId: message.id,
                        )
                      : null;

                  final senderId = data['senderId'] is String
                      ? data['senderId'] as String
                      : '';

                  final senderName = data['senderName'] is String
                      ? data['senderName'] as String
                      : data['senderEmail'] is String
                      ? data['senderEmail'] as String
                      : 'Пользователь';

                  final createdAt = data['createdAt'];
                  final timeText = formatMessageTime(createdAt);
                  final isMe = senderId == currentUser?.uid;

                  final senderRole = widget.memberRoles[senderId] ?? 'member';

                  final hiddenFor = data['hiddenFor'];

                  final isHiddenForCurrentUser =
                      currentUser != null &&
                      hiddenFor is Map<String, dynamic> &&
                      hiddenFor[currentUser.uid] is Timestamp;

                  final isLocallyHidden = _locallyHiddenMessageIds.contains(
                    message.id,
                  );

                  final visibility = isLocallyHidden
                      ? MessageVisibilityState.hiddenForCurrentUser
                      : data['deletedForEveryone'] == true
                      ? MessageVisibilityState.deletedForEveryone
                      : isHiddenForCurrentUser
                      ? MessageVisibilityState.hiddenForCurrentUser
                      : MessageVisibilityState.visible;

                  final presentation = MessagePresentation(
                    id: message.id,
                    text: text,
                    senderId: senderId,
                    senderName: senderName,
                    createdAt: createdAt is Timestamp
                        ? createdAt.toDate()
                        : null,
                    visibility: visibility,
                    isImageMessage: messageType == 'image',
                    imageMetadata: imageMetadata,
                  );

                  return MessageItem(
                    key: _messageItemKey(message.id),
                    message: presentation,
                    senderRole: senderRole,
                    timeText: timeText,
                    isMe: isMe,
                    dateLabel: dateLabelsByMessageId[message.id],
                    onLongPress: presentation.isVisible
                        ? () {
                            unawaited(
                              _showMessageActions(
                                message: presentation,
                                isMe: isMe,
                              ),
                            );
                          }
                        : null,
                  );
                },
              ),
            ),
          ),
        ),
        if (_isLoadingOlder)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            top: shouldOffsetLoadingIndicator ? 52 : 8,
            left: 0,
            right: 0,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ChatScrollDateIndicator(
            label: _scrollDateLabel,
            isVisible: _isScrollDateVisible,
          ),
        ),
      ],
    );
  }
}
