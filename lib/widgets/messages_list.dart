import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import 'message_bubble.dart';

class MessagesList extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> memberRoles;
  final Timestamp? visibleAfter;

  const MessagesList({
    super.key,
    required this.chatId,
    required this.memberRoles,
    this.visibleAfter,
  });

  @override
  State<MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<MessagesList> {
  static const int _pageSize = 40;
  static const double _loadMoreThreshold = 240;

  final chatService = ChatService();
  final scrollController = ScrollController();
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _messagesById =
      {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _latestMessagesSubscription;
  QueryDocumentSnapshot<Map<String, dynamic>>? _oldestLoadedDocument;

  bool _isInitialLoading = true;
  bool _isLoadingOlder = false;
  bool _hasMore = true;
  bool _hasRequestedOlderPage = false;
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

    if (oldWidget.chatId != widget.chatId ||
        oldWidget.visibleAfter != widget.visibleAfter) {
      unawaited(_restartSubscription());
    }
  }

  Future<void> _restartSubscription() async {
    await _latestMessagesSubscription?.cancel();

    if (!mounted) return;

    setState(() {
      _messagesById.clear();
      _oldestLoadedDocument = null;
      _isInitialLoading = true;
      _isLoadingOlder = false;
      _hasMore = true;
      _hasRequestedOlderPage = false;
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
            if (!mounted) return;

            setState(() {
              _isInitialLoading = false;
              _initialLoadError = error;
            });
          },
        );
  }

  void _handleLatestSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) return;

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
      _scrollToBottom(animated: false);
    } else if (addedMessage && wasNearBottom) {
      _scrollToBottom();
    }
  }

  void _handleScroll() {
    if (!scrollController.hasClients) return;

    if (scrollController.position.pixels <= _loadMoreThreshold) {
      unawaited(_loadOlderMessages());
    }
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

      if (!mounted) return;

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
          if (!scrollController.hasClients) return;

          final newMaxScrollExtent = scrollController.position.maxScrollExtent;
          final addedExtent = newMaxScrollExtent - previousMaxScrollExtent;

          scrollController.jumpTo(previousPixels + addedExtent);
        });
      }
    } catch (_) {
      if (!mounted) return;

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

  void _updateOldestLoadedDocument() {
    final messages = _sortedMessages;
    _oldestLoadedDocument = messages.isEmpty ? null : messages.first;
  }

  bool get _isNearBottom {
    if (!scrollController.hasClients) return true;

    final position = scrollController.position;
    return position.maxScrollExtent - position.pixels < 180;
  }

  String formatMessageTime(dynamic createdAt) {
    if (createdAt == null || createdAt is! Timestamp) return '';

    final dateTime = createdAt.toDate();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void _scrollToBottom({bool animated = true}) {
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
    _latestMessagesSubscription?.cancel();
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final messages = _sortedMessages;

    if (_isInitialLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_initialLoadError != null && messages.isEmpty) {
      return const Center(child: Text('Не удалось загрузить сообщения'));
    }

    if (messages.isEmpty) {
      return const Center(child: Text('Сообщений пока нет'));
    }

    return Stack(
      children: [
        ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final data = message.data();

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
        ),
        if (_isLoadingOlder)
          const Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
