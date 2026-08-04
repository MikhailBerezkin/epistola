import 'dart:async';

import 'package:epistola/services/chat/private_typing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const chatId = 'user-1_user-2';
  const currentUserId = 'user-1';
  const peerUserId = 'user-2';

  group('PrivateTypingService', () {
    test('prepare skips when user is unauthenticated', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: null);
      final service = backend.createService();

      final result = await service.prepare(chatId: chatId);

      expect(result, PrivateTypingPreparationResult.skippedUnauthenticated);
      expect(backend.ensureAccessCalls, isEmpty);
      expect(backend.registerDisconnectCalls, isEmpty);
    });

    test('prepare ensures access and registers onDisconnect', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      final result = await service.prepare(chatId: chatId);

      expect(result, PrivateTypingPreparationResult.ready);
      expect(backend.ensureAccessCalls, <String>[chatId]);
      expect(backend.registerDisconnectCalls, <_TypingCall>[
        const _TypingCall(chatId: chatId, userId: currentUserId),
      ]);
    });

    test('prepare does not repeat an already prepared session', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      await service.prepare(chatId: chatId);

      final result = await service.prepare(chatId: chatId);

      expect(result, PrivateTypingPreparationResult.alreadyReady);
      expect(backend.ensureAccessCalls, <String>[chatId]);
      expect(backend.registerDisconnectCalls, hasLength(1));
    });

    test('startTyping prepares session and writes timestamp', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      final result = await service.startTyping(chatId: chatId);

      expect(result, PrivateTypingWriteResult.written);
      expect(backend.ensureAccessCalls, <String>[chatId]);
      expect(backend.registerDisconnectCalls, hasLength(1));
      expect(backend.writeTimestampCalls, <_TypingCall>[
        const _TypingCall(chatId: chatId, userId: currentUserId),
      ]);
    });

    test('startTyping reuses prepared session', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      await service.prepare(chatId: chatId);

      await service.startTyping(chatId: chatId);
      await service.startTyping(chatId: chatId);

      expect(backend.ensureAccessCalls, <String>[chatId]);
      expect(backend.registerDisconnectCalls, hasLength(1));
      expect(backend.writeTimestampCalls, hasLength(2));
    });

    test('startTyping skips when user is unauthenticated', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: null);
      final service = backend.createService();

      final result = await service.startTyping(chatId: chatId);

      expect(result, PrivateTypingWriteResult.skippedUnauthenticated);
      expect(backend.ensureAccessCalls, isEmpty);
      expect(backend.writeTimestampCalls, isEmpty);
    });

    test('stopTyping skips an unprepared session', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      final result = await service.stopTyping(chatId: chatId);

      expect(result, PrivateTypingStopResult.skippedNotPrepared);
      expect(backend.removeStateCalls, isEmpty);
    });

    test('stopTyping removes own prepared state', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      await service.prepare(chatId: chatId);

      final result = await service.stopTyping(chatId: chatId);

      expect(result, PrivateTypingStopResult.stopped);
      expect(backend.removeStateCalls, <_TypingCall>[
        const _TypingCall(chatId: chatId, userId: currentUserId),
      ]);
      expect(backend.cancelDisconnectCalls, isEmpty);
    });

    test('close removes state and cancels onDisconnect', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      await service.prepare(chatId: chatId);

      final result = await service.close(chatId: chatId);

      expect(result, PrivateTypingCloseResult.closed);
      expect(backend.removeStateCalls, <_TypingCall>[
        const _TypingCall(chatId: chatId, userId: currentUserId),
      ]);
      expect(backend.cancelDisconnectCalls, <_TypingCall>[
        const _TypingCall(chatId: chatId, userId: currentUserId),
      ]);
    });

    test('close allows the session to be prepared again', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      await service.prepare(chatId: chatId);
      await service.close(chatId: chatId);

      final result = await service.prepare(chatId: chatId);

      expect(result, PrivateTypingPreparationResult.ready);
      expect(backend.ensureAccessCalls, <String>[chatId, chatId]);
      expect(backend.registerDisconnectCalls, hasLength(2));
    });

    test('watchPeerState subscribes only to requested peer', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      final values = <Object?>[];

      final subscription = service
          .watchPeerState(chatId: chatId, peerUserId: peerUserId)
          .listen(values.add);

      backend.peerStateController.add(123456789);

      await Future<void>.delayed(Duration.zero);

      expect(backend.peerStreamCalls, <_TypingCall>[
        const _TypingCall(chatId: chatId, userId: peerUserId),
      ]);
      expect(values, <Object?>[123456789]);

      await subscription.cancel();
      await backend.dispose();
    });

    test('watchPeerState rejects unauthenticated user', () {
      final backend = _FakePrivateTypingBackend(currentUserId: null);
      final service = backend.createService();

      expect(
        () => service.watchPeerState(chatId: chatId, peerUserId: peerUserId),
        throwsStateError,
      );
    });

    test('watchPeerState rejects current user as peer', () {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      expect(
        () => service.watchPeerState(chatId: chatId, peerUserId: currentUserId),
        throwsArgumentError,
      );
    });

    test('prepare rejects an invalid chat key', () async {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      await expectLater(
        service.prepare(chatId: 'invalid/chat'),
        throwsArgumentError,
      );
    });

    test('watchPeerState rejects an invalid peer key', () {
      final backend = _FakePrivateTypingBackend(currentUserId: currentUserId);
      final service = backend.createService();

      expect(
        () =>
            service.watchPeerState(chatId: chatId, peerUserId: 'invalid.peer'),
        throwsArgumentError,
      );
    });
  });
}

final class _FakePrivateTypingBackend {
  _FakePrivateTypingBackend({required this.currentUserId});

  String? currentUserId;

  final List<String> ensureAccessCalls = <String>[];

  final List<_TypingCall> registerDisconnectCalls = <_TypingCall>[];

  final List<_TypingCall> cancelDisconnectCalls = <_TypingCall>[];

  final List<_TypingCall> writeTimestampCalls = <_TypingCall>[];

  final List<_TypingCall> removeStateCalls = <_TypingCall>[];

  final List<_TypingCall> peerStreamCalls = <_TypingCall>[];

  final StreamController<Object?> peerStateController =
      StreamController<Object?>.broadcast();

  PrivateTypingService createService() {
    return PrivateTypingService(
      currentUserIdProvider: () => currentUserId,
      ensureAccess: ({required String chatId}) async {
        ensureAccessCalls.add(chatId);
      },
      registerDisconnect:
          ({required String chatId, required String userId}) async {
            registerDisconnectCalls.add(
              _TypingCall(chatId: chatId, userId: userId),
            );
          },
      cancelDisconnect:
          ({required String chatId, required String userId}) async {
            cancelDisconnectCalls.add(
              _TypingCall(chatId: chatId, userId: userId),
            );
          },
      writeTimestamp: ({required String chatId, required String userId}) async {
        writeTimestampCalls.add(_TypingCall(chatId: chatId, userId: userId));
      },
      removeState: ({required String chatId, required String userId}) async {
        removeStateCalls.add(_TypingCall(chatId: chatId, userId: userId));
      },
      peerStateStreamProvider:
          ({required String chatId, required String peerUserId}) {
            peerStreamCalls.add(
              _TypingCall(chatId: chatId, userId: peerUserId),
            );

            return peerStateController.stream;
          },
    );
  }

  Future<void> dispose() {
    return peerStateController.close();
  }
}

final class _TypingCall {
  const _TypingCall({required this.chatId, required this.userId});

  final String chatId;
  final String userId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _TypingCall &&
            other.chatId == chatId &&
            other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(chatId, userId);

  @override
  String toString() {
    return '_TypingCall('
        'chatId: $chatId, '
        'userId: $userId'
        ')';
  }
}
