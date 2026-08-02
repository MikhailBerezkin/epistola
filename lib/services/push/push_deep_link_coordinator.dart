import 'dart:async';
import 'dart:collection';

import '../../domain/models/push_deep_link_request.dart';
import 'push_deep_link_resolver.dart';

typedef PushDeepLinkReadinessProvider = bool Function();

typedef PushDeepLinkDestinationOpener =
    Future<void> Function(PushDeepLinkDestination destination);

typedef PushDeepLinkUnavailableHandler =
    void Function(PushDeepLinkRequest request);

typedef PushDeepLinkErrorHandler =
    void Function(Object error, StackTrace stackTrace);

class PushDeepLinkCoordinator {
  PushDeepLinkCoordinator({
    required PushDeepLinkResolver resolver,
    required PushDeepLinkReadinessProvider isNavigationReady,
    required PushDeepLinkDestinationOpener openDestination,
    PushDeepLinkUnavailableHandler? onUnavailable,
    PushDeepLinkErrorHandler? onError,
  }) : this._(
         resolver: resolver,
         isNavigationReady: isNavigationReady,
         openDestination: openDestination,
         onUnavailable: onUnavailable,
         onError: onError,
       );

  PushDeepLinkCoordinator._({
    required this._resolver,
    required this._isNavigationReady,
    required this._openDestination,
    this._onUnavailable,
    this._onError,
  });

  final PushDeepLinkResolver _resolver;
  final PushDeepLinkReadinessProvider _isNavigationReady;
  final PushDeepLinkDestinationOpener _openDestination;
  final PushDeepLinkUnavailableHandler? _onUnavailable;
  final PushDeepLinkErrorHandler? _onError;

  final Queue<PushDeepLinkRequest> _pendingRequests =
      Queue<PushDeepLinkRequest>();

  final Set<String> _queuedChatIds = <String>{};
  final Set<String> _openedChatIds = <String>{};

  bool _isDraining = false;

  bool get hasPendingRequests => _pendingRequests.isNotEmpty;

  Future<void> handle(PushDeepLinkRequest request) async {
    if (_queuedChatIds.contains(request.chatId) ||
        _openedChatIds.contains(request.chatId)) {
      return;
    }

    _pendingRequests.addLast(request);
    _queuedChatIds.add(request.chatId);

    await flush();
  }

  Future<void> flush() async {
    if (_isDraining || !_isNavigationReady()) {
      return;
    }

    _isDraining = true;

    try {
      while (_pendingRequests.isNotEmpty && _isNavigationReady()) {
        final request = _pendingRequests.removeFirst();
        _queuedChatIds.remove(request.chatId);

        if (_openedChatIds.contains(request.chatId)) {
          continue;
        }

        PushDeepLinkDestination? destination;

        try {
          destination = await _resolver.resolve(request);
        } catch (error, stackTrace) {
          _onError?.call(error, stackTrace);
          continue;
        }

        if (destination == null) {
          _onUnavailable?.call(request);
          continue;
        }

        _open(destination);
      }
    } finally {
      _isDraining = false;
    }
  }

  void clearPending() {
    _pendingRequests.clear();
    _queuedChatIds.clear();
  }

  void _open(PushDeepLinkDestination destination) {
    final chatId = destination.chatId;

    _openedChatIds.add(chatId);

    try {
      final navigation = _openDestination(destination);

      unawaited(
        navigation
            .then<void>(
              (_) {},
              onError: (Object error, StackTrace stackTrace) {
                _onError?.call(error, stackTrace);
              },
            )
            .whenComplete(() {
              _openedChatIds.remove(chatId);
            }),
      );
    } catch (error, stackTrace) {
      _openedChatIds.remove(chatId);
      _onError?.call(error, stackTrace);
    }
  }
}
