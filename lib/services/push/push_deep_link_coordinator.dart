import 'dart:async';
import 'dart:collection';

import '../../domain/models/push_deep_link_request.dart';
import 'push_deep_link_resolver.dart';

typedef PushDeepLinkReadinessProvider = bool Function();

typedef PushDeepLinkDestinationOpener =
    Future<void> Function(PushDeepLinkDestination destination);

typedef PushDeepLinkSpacesBarOpener = Future<void> Function(String messageId);

typedef PushDeepLinkUnavailableHandler =
    void Function(PushDeepLinkRequest request);

typedef PushDeepLinkErrorHandler =
    void Function(Object error, StackTrace stackTrace);

class PushDeepLinkCoordinator {
  PushDeepLinkCoordinator({
    required PushDeepLinkResolver resolver,
    required PushDeepLinkReadinessProvider isNavigationReady,
    required PushDeepLinkDestinationOpener openDestination,
    PushDeepLinkSpacesBarOpener? openSpacesBarMessage,
    PushDeepLinkUnavailableHandler? onUnavailable,
    PushDeepLinkErrorHandler? onError,
  }) : this._(
         resolver: resolver,
         isNavigationReady: isNavigationReady,
         openDestination: openDestination,
         openSpacesBarMessage: openSpacesBarMessage,
         onUnavailable: onUnavailable,
         onError: onError,
       );

  PushDeepLinkCoordinator._({
    required this._resolver,
    required this._isNavigationReady,
    required this._openDestination,
    this._openSpacesBarMessage,
    this._onUnavailable,
    this._onError,
  });

  final PushDeepLinkResolver _resolver;
  final PushDeepLinkReadinessProvider _isNavigationReady;
  final PushDeepLinkDestinationOpener _openDestination;
  final PushDeepLinkSpacesBarOpener? _openSpacesBarMessage;
  final PushDeepLinkUnavailableHandler? _onUnavailable;
  final PushDeepLinkErrorHandler? _onError;

  final Queue<PushDeepLinkRequest> _pendingRequests =
      Queue<PushDeepLinkRequest>();

  final Set<String> _queuedTargetKeys = <String>{};
  final Set<String> _openedTargetKeys = <String>{};

  bool _isDraining = false;

  bool get hasPendingRequests => _pendingRequests.isNotEmpty;

  Future<void> handle(PushDeepLinkRequest request) async {
    final targetKey = request.deduplicationKey;

    if (_queuedTargetKeys.contains(targetKey) ||
        _openedTargetKeys.contains(targetKey)) {
      return;
    }

    _pendingRequests.addLast(request);
    _queuedTargetKeys.add(targetKey);

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
        final targetKey = request.deduplicationKey;

        _queuedTargetKeys.remove(targetKey);

        if (_openedTargetKeys.contains(targetKey)) {
          continue;
        }

        if (request.isSpacesBar) {
          await _resolveAndOpenSpacesBar(
            request: request,
            targetKey: targetKey,
          );

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

        _openTracked(
          targetKey: targetKey,
          operation: () => _openDestination(destination!),
        );
      }
    } finally {
      _isDraining = false;
    }
  }

  Future<void> _resolveAndOpenSpacesBar({
    required PushDeepLinkRequest request,
    required String targetKey,
  }) async {
    String? messageId;

    try {
      messageId = await _resolver.resolveSpacesBarMessageId(request);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
      return;
    }

    final opener = _openSpacesBarMessage;

    if (messageId == null || opener == null) {
      _onUnavailable?.call(request);
      return;
    }

    _openTracked(targetKey: targetKey, operation: () => opener(messageId!));
  }

  void clearPending() {
    _pendingRequests.clear();
    _queuedTargetKeys.clear();
  }

  void _openTracked({
    required String targetKey,
    required Future<void> Function() operation,
  }) {
    _openedTargetKeys.add(targetKey);

    try {
      final navigation = operation();

      unawaited(
        navigation
            .then<void>(
              (_) {},
              onError: (Object error, StackTrace stackTrace) {
                _onError?.call(error, stackTrace);
              },
            )
            .whenComplete(() {
              _openedTargetKeys.remove(targetKey);
            }),
      );
    } catch (error, stackTrace) {
      _openedTargetKeys.remove(targetKey);
      _onError?.call(error, stackTrace);
    }
  }
}
