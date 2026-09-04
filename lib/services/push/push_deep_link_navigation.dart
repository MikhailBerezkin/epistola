import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../screens/chat_screen.dart';
import '../../screens/home_screen.dart';
import 'push_deep_link_coordinator.dart';
import 'push_deep_link_resolver.dart';

class PushDeepLinkNavigation {
  PushDeepLinkNavigation({PushDeepLinkResolver? resolver})
    : _resolver = resolver ?? PushDeepLinkResolver.firebase() {
    _coordinator = PushDeepLinkCoordinator(
      resolver: _resolver,
      isNavigationReady: _isNavigationReady,
      openDestination: _openDestination,
      openSpacesBarMessage: _openSpacesBarMessage,
      onUnavailable: (request) {
        if (kDebugMode) {
          debugPrint('Push deep link is unavailable: $request');
        }
      },
      onError: (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Push deep link error: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      },
    );
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final PushDeepLinkResolver _resolver;

  late final PushDeepLinkCoordinator _coordinator;

  bool _navigationReady = false;

  PushDeepLinkCoordinator get coordinator => _coordinator;

  void markNavigationReady() {
    _navigationReady = true;

    _coordinator.flush();
  }

  void markNavigationUnavailable() {
    _navigationReady = false;
  }

  bool _isNavigationReady() {
    return _navigationReady &&
        navigatorKey.currentState != null &&
        navigatorKey.currentContext != null;
  }

  Future<void> _openDestination(PushDeepLinkDestination destination) async {
    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          chatId: destination.chatId,
          chatName: destination.chatName,
          peerUser: destination.isPrivateChat ? destination.peerUser : null,
        ),
      ),
    );
  }

  Future<void> _openSpacesBarMessage(String messageId) async {
    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(
          spacesBarTargetMessageId: messageId,
          allowRoutePop: true,
        ),
      ),
    );
  }
}
