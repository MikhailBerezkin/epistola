import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/models/epistola_system_message.dart';
import '../services/system_chat/epistola_system_chat_service.dart';
import '../services/system_chat/system_chat_dependencies.dart';
import '../widgets/system_chat/epistola_system_messages_list.dart';

class EpistolaSystemChatScreen extends StatefulWidget {
  const EpistolaSystemChatScreen({super.key, this.service, this.userId});

  final EpistolaSystemChatService? service;

  /// Используется для тестов.
  /// В приложении UID берётся из FirebaseAuth.
  final String? userId;

  @override
  State<EpistolaSystemChatScreen> createState() =>
      _EpistolaSystemChatScreenState();
}

class _EpistolaSystemChatScreenState extends State<EpistolaSystemChatScreen> {
  static const double _nearBottomThreshold = 160;

  late final EpistolaSystemChatService _service;
  late final ScrollController _scrollController;

  StreamSubscription<List<EpistolaSystemMessage>>? _messagesSubscription;

  List<EpistolaSystemMessage> _messages = const <EpistolaSystemMessage>[];

  bool _isLoading = true;
  Object? _error;

  String get _currentUserId {
    return (widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '')
        .trim();
  }

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? createEpistolaSystemChatService();
    _scrollController = ScrollController();

    _startWatch();
  }

  void _startWatch() {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      _setWatchError(
        StateError('Epistola system chat requires an authenticated user.'),
      );
      return;
    }

    try {
      _messagesSubscription = _service
          .watch(userId: userId)
          .listen(_handleMessages, onError: _handleWatchError);
    } catch (error) {
      _setWatchError(error);
    }
  }

  void _handleMessages(List<EpistolaSystemMessage> messages) {
    if (!mounted) {
      return;
    }

    final wasInitialLoad = _isLoading;
    final shouldScrollToBottom = wasInitialLoad || _isNearBottom;

    setState(() {
      _messages = messages;
      _isLoading = false;
      _error = null;
    });

    if (messages.isNotEmpty && shouldScrollToBottom) {
      _scrollToBottom(animated: !wasInitialLoad);
    }
  }

  void _handleWatchError(Object error, StackTrace stackTrace) {
    _setWatchError(error);
  }

  void _setWatchError(Object error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _error = error;
    });
  }

  Future<void> _retry() async {
    final subscription = _messagesSubscription;

    _messagesSubscription = null;

    if (subscription != null) {
      await subscription.cancel();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _messages = const <EpistolaSystemMessage>[];
      _isLoading = true;
      _error = null;
    });

    _startWatch();
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) {
      return true;
    }

    final position = _scrollController.position;

    return position.maxScrollExtent - position.pixels < _nearBottomThreshold;
  }

  void _scrollToBottom({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final bottom = _scrollController.position.maxScrollExtent;

      if (animated) {
        _scrollController.animateTo(
          bottom,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(bottom);
      }
    });
  }

  @override
  void dispose() {
    final subscription = _messagesSubscription;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Epistola')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _messages.isEmpty) {
      return const Center(
        key: ValueKey('epistola-system-chat-loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _messages.isEmpty) {
      return Center(
        key: const ValueKey('epistola-system-chat-error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Не удалось загрузить технические сообщения',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('epistola-system-chat-retry'),
                onPressed: _retry,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        key: ValueKey('epistola-system-chat-empty'),
        child: Text('Технических сообщений пока нет'),
      );
    }

    return EpistolaSystemMessagesList(
      messages: _messages,
      controller: _scrollController,
    );
  }
}
