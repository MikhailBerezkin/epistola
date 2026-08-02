import 'dart:async';

import 'package:epistola/domain/models/push_deep_link_request.dart';
import 'package:epistola/services/push/push_deep_link_coordinator.dart';
import 'package:epistola/services/push/push_deep_link_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushDeepLinkCoordinator', () {
    test('keeps a request pending until navigation is ready', () async {
      var isReady = false;
      final openedChatIds = <String>[];

      final coordinator = PushDeepLinkCoordinator(
        resolver: _groupResolver(),
        isNavigationReady: () => isReady,
        openDestination: (destination) async {
          openedChatIds.add(destination.chatId);
        },
      );

      await coordinator.handle(_request('group-chat-1'));

      expect(coordinator.hasPendingRequests, isTrue);
      expect(openedChatIds, isEmpty);

      isReady = true;
      await coordinator.flush();

      expect(coordinator.hasPendingRequests, isFalse);
      expect(openedChatIds, ['group-chat-1']);
    });

    test('does not queue the same chat more than once', () async {
      var isReady = false;
      final openedChatIds = <String>[];

      final coordinator = PushDeepLinkCoordinator(
        resolver: _groupResolver(),
        isNavigationReady: () => isReady,
        openDestination: (destination) async {
          openedChatIds.add(destination.chatId);
        },
      );

      final request = _request('group-chat-1');

      await coordinator.handle(request);
      await coordinator.handle(request);

      isReady = true;
      await coordinator.flush();

      expect(openedChatIds, ['group-chat-1']);
    });

    test('ignores a duplicate while the chat route is still open', () async {
      final navigation = Completer<void>();
      final openedChatIds = <String>[];

      final coordinator = PushDeepLinkCoordinator(
        resolver: _groupResolver(),
        isNavigationReady: () => true,
        openDestination: (destination) {
          openedChatIds.add(destination.chatId);
          return navigation.future;
        },
      );

      final request = _request('group-chat-1');

      await coordinator.handle(request);
      await coordinator.handle(request);

      expect(openedChatIds, ['group-chat-1']);

      navigation.complete();
      await Future<void>.delayed(Duration.zero);

      await coordinator.handle(request);

      expect(openedChatIds, ['group-chat-1', 'group-chat-1']);
    });

    test('reports an unavailable chat without opening a route', () async {
      final unavailableChatIds = <String>[];
      final openedChatIds = <String>[];

      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => 'current-user',
        loadChat: (_) async => null,
        loadUser: (_) async => null,
      );

      final coordinator = PushDeepLinkCoordinator(
        resolver: resolver,
        isNavigationReady: () => true,
        openDestination: (destination) async {
          openedChatIds.add(destination.chatId);
        },
        onUnavailable: (request) {
          unavailableChatIds.add(request.chatId);
        },
      );

      await coordinator.handle(_request('missing-chat'));

      expect(unavailableChatIds, ['missing-chat']);
      expect(openedChatIds, isEmpty);
    });

    test('reports resolver errors and allows a later retry', () async {
      var loadAttempts = 0;
      final errors = <Object>[];
      final openedChatIds = <String>[];

      final resolver = PushDeepLinkResolver(
        currentUserIdProvider: () => 'current-user',
        loadChat: (_) async {
          loadAttempts += 1;

          if (loadAttempts == 1) {
            throw StateError('Temporary Firestore failure');
          }

          return {
            'type': 'group',
            'name': 'Рабочая группа',
            'memberIds': ['current-user'],
          };
        },
        loadUser: (_) async => null,
      );

      final coordinator = PushDeepLinkCoordinator(
        resolver: resolver,
        isNavigationReady: () => true,
        openDestination: (destination) async {
          openedChatIds.add(destination.chatId);
        },
        onError: (error, _) {
          errors.add(error);
        },
      );

      final request = _request('group-chat-1');

      await coordinator.handle(request);

      expect(errors, hasLength(1));
      expect(openedChatIds, isEmpty);

      await coordinator.handle(request);

      expect(loadAttempts, 2);
      expect(openedChatIds, ['group-chat-1']);
    });

    test('clearPending removes queued requests', () async {
      var isReady = false;
      final openedChatIds = <String>[];

      final coordinator = PushDeepLinkCoordinator(
        resolver: _groupResolver(),
        isNavigationReady: () => isReady,
        openDestination: (destination) async {
          openedChatIds.add(destination.chatId);
        },
      );

      await coordinator.handle(_request('group-chat-1'));
      await coordinator.handle(_request('group-chat-2'));

      expect(coordinator.hasPendingRequests, isTrue);

      coordinator.clearPending();

      expect(coordinator.hasPendingRequests, isFalse);

      isReady = true;
      await coordinator.flush();

      expect(openedChatIds, isEmpty);
    });
  });
}

PushDeepLinkResolver _groupResolver() {
  return PushDeepLinkResolver(
    currentUserIdProvider: () => 'current-user',
    loadChat: (_) async => {
      'type': 'group',
      'name': 'Рабочая группа',
      'memberIds': ['current-user'],
    },
    loadUser: (_) async => null,
  );
}

PushDeepLinkRequest _request(String chatId) {
  return PushDeepLinkRequest.tryParseChatId(chatId)!;
}
