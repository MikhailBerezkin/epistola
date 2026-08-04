import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

typedef PrivateTypingCurrentUserIdProvider = String? Function();

typedef PrivateTypingAccessEnsurer =
    Future<void> Function({required String chatId});

typedef PrivateTypingDisconnectRegistrar =
    Future<void> Function({required String chatId, required String userId});

typedef PrivateTypingDisconnectCanceller =
    Future<void> Function({required String chatId, required String userId});

typedef PrivateTypingTimestampWriter =
    Future<void> Function({required String chatId, required String userId});

typedef PrivateTypingStateRemover =
    Future<void> Function({required String chatId, required String userId});

typedef PrivateTypingPeerStateStreamProvider =
    Stream<Object?> Function({
      required String chatId,
      required String peerUserId,
    });

enum PrivateTypingPreparationResult {
  ready,
  alreadyReady,
  skippedUnauthenticated,
}

enum PrivateTypingWriteResult { written, skippedUnauthenticated }

enum PrivateTypingStopResult {
  stopped,
  skippedUnauthenticated,
  skippedNotPrepared,
}

enum PrivateTypingCloseResult {
  closed,
  skippedUnauthenticated,
  skippedNotPrepared,
}

final class PrivateTypingService {
  factory PrivateTypingService({
    required PrivateTypingCurrentUserIdProvider currentUserIdProvider,
    required PrivateTypingAccessEnsurer ensureAccess,
    required PrivateTypingDisconnectRegistrar registerDisconnect,
    required PrivateTypingDisconnectCanceller cancelDisconnect,
    required PrivateTypingTimestampWriter writeTimestamp,
    required PrivateTypingStateRemover removeState,
    required PrivateTypingPeerStateStreamProvider peerStateStreamProvider,
  }) {
    return PrivateTypingService._(
      currentUserIdProvider,
      ensureAccess,
      registerDisconnect,
      cancelDisconnect,
      writeTimestamp,
      removeState,
      peerStateStreamProvider,
    );
  }

  PrivateTypingService._(
    this._currentUserIdProvider,
    this._ensureAccess,
    this._registerDisconnect,
    this._cancelDisconnect,
    this._writeTimestamp,
    this._removeState,
    this._peerStateStreamProvider,
  );

  factory PrivateTypingService.firebase({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirebaseDatabase? database,
  }) {
    final resolvedAuth = auth ?? FirebaseAuth.instance;

    final resolvedFunctions =
        functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

    final resolvedDatabase = database ?? FirebaseDatabase.instance;

    DatabaseReference typingReference({
      required String chatId,
      required String userId,
    }) {
      return resolvedDatabase.ref('privateTyping/$chatId/$userId');
    }

    return PrivateTypingService(
      currentUserIdProvider: () {
        return resolvedAuth.currentUser?.uid;
      },
      ensureAccess: ({required String chatId}) async {
        final callable = resolvedFunctions.httpsCallable(
          'ensurePrivateTypingAccess',
        );

        final result = await callable.call(<String, dynamic>{'chatId': chatId});

        final data = result.data;

        if (data is! Map || data['granted'] != true) {
          throw StateError(
            'ensurePrivateTypingAccess returned '
            'an invalid response.',
          );
        }
      },
      registerDisconnect: ({required String chatId, required String userId}) {
        return typingReference(
          chatId: chatId,
          userId: userId,
        ).onDisconnect().remove();
      },
      cancelDisconnect: ({required String chatId, required String userId}) {
        return typingReference(
          chatId: chatId,
          userId: userId,
        ).onDisconnect().cancel();
      },
      writeTimestamp: ({required String chatId, required String userId}) {
        return typingReference(
          chatId: chatId,
          userId: userId,
        ).set(ServerValue.timestamp);
      },
      removeState: ({required String chatId, required String userId}) {
        return typingReference(chatId: chatId, userId: userId).remove();
      },
      peerStateStreamProvider:
          ({required String chatId, required String peerUserId}) {
            return typingReference(
              chatId: chatId,
              userId: peerUserId,
            ).onValue.map((event) => event.snapshot.value);
          },
    );
  }

  final PrivateTypingCurrentUserIdProvider _currentUserIdProvider;

  final PrivateTypingAccessEnsurer _ensureAccess;

  final PrivateTypingDisconnectRegistrar _registerDisconnect;

  final PrivateTypingDisconnectCanceller _cancelDisconnect;

  final PrivateTypingTimestampWriter _writeTimestamp;

  final PrivateTypingStateRemover _removeState;

  final PrivateTypingPeerStateStreamProvider _peerStateStreamProvider;

  final Set<String> _preparedSessions = <String>{};

  Future<PrivateTypingPreparationResult> prepare({
    required String chatId,
  }) async {
    final normalizedChatId = _normalizeRequiredKey(
      value: chatId,
      argumentName: 'chatId',
    );

    final currentUserId = _readCurrentUserId();

    if (currentUserId == null) {
      return PrivateTypingPreparationResult.skippedUnauthenticated;
    }

    return _prepareForUser(chatId: normalizedChatId, userId: currentUserId);
  }

  Future<PrivateTypingWriteResult> startTyping({required String chatId}) async {
    final normalizedChatId = _normalizeRequiredKey(
      value: chatId,
      argumentName: 'chatId',
    );

    final currentUserId = _readCurrentUserId();

    if (currentUserId == null) {
      return PrivateTypingWriteResult.skippedUnauthenticated;
    }

    await _prepareForUser(chatId: normalizedChatId, userId: currentUserId);

    await _writeTimestamp(chatId: normalizedChatId, userId: currentUserId);

    return PrivateTypingWriteResult.written;
  }

  Future<PrivateTypingStopResult> stopTyping({required String chatId}) async {
    final normalizedChatId = _normalizeRequiredKey(
      value: chatId,
      argumentName: 'chatId',
    );

    final currentUserId = _readCurrentUserId();

    if (currentUserId == null) {
      return PrivateTypingStopResult.skippedUnauthenticated;
    }

    final sessionKey = _sessionKey(
      chatId: normalizedChatId,
      userId: currentUserId,
    );

    if (!_preparedSessions.contains(sessionKey)) {
      return PrivateTypingStopResult.skippedNotPrepared;
    }

    await _removeState(chatId: normalizedChatId, userId: currentUserId);

    return PrivateTypingStopResult.stopped;
  }

  Future<PrivateTypingCloseResult> close({required String chatId}) async {
    final normalizedChatId = _normalizeRequiredKey(
      value: chatId,
      argumentName: 'chatId',
    );

    final currentUserId = _readCurrentUserId();

    if (currentUserId == null) {
      return PrivateTypingCloseResult.skippedUnauthenticated;
    }

    final sessionKey = _sessionKey(
      chatId: normalizedChatId,
      userId: currentUserId,
    );

    if (!_preparedSessions.contains(sessionKey)) {
      return PrivateTypingCloseResult.skippedNotPrepared;
    }

    await _removeState(chatId: normalizedChatId, userId: currentUserId);

    await _cancelDisconnect(chatId: normalizedChatId, userId: currentUserId);

    _preparedSessions.remove(sessionKey);

    return PrivateTypingCloseResult.closed;
  }

  Stream<Object?> watchPeerState({
    required String chatId,
    required String peerUserId,
  }) {
    final normalizedChatId = _normalizeRequiredKey(
      value: chatId,
      argumentName: 'chatId',
    );

    final normalizedPeerUserId = _normalizeRequiredKey(
      value: peerUserId,
      argumentName: 'peerUserId',
    );

    final currentUserId = _readCurrentUserId();

    if (currentUserId == null) {
      throw StateError('Authentication is required to watch typing state.');
    }

    if (currentUserId == normalizedPeerUserId) {
      throw ArgumentError.value(
        peerUserId,
        'peerUserId',
        'peerUserId must differ from the current user.',
      );
    }

    return _peerStateStreamProvider(
      chatId: normalizedChatId,
      peerUserId: normalizedPeerUserId,
    );
  }

  Future<PrivateTypingPreparationResult> _prepareForUser({
    required String chatId,
    required String userId,
  }) async {
    final sessionKey = _sessionKey(chatId: chatId, userId: userId);

    if (_preparedSessions.contains(sessionKey)) {
      return PrivateTypingPreparationResult.alreadyReady;
    }

    await _ensureAccess(chatId: chatId);

    await _registerDisconnect(chatId: chatId, userId: userId);

    _preparedSessions.add(sessionKey);

    return PrivateTypingPreparationResult.ready;
  }

  String? _readCurrentUserId() {
    final currentUserId = _currentUserIdProvider()?.trim() ?? '';

    if (!_isValidRealtimeDatabaseKey(currentUserId)) {
      return null;
    }

    return currentUserId;
  }

  static String _sessionKey({required String chatId, required String userId}) {
    return '$chatId\n$userId';
  }

  static bool _isValidRealtimeDatabaseKey(String value) {
    if (value.isEmpty || value != value.trim()) {
      return false;
    }

    const forbiddenCharacters = <String>['.', '#', r'$', '[', ']', '/'];

    return !forbiddenCharacters.any(value.contains);
  }

  static String _normalizeRequiredKey({
    required String value,
    required String argumentName,
  }) {
    final normalizedValue = value.trim();

    if (!_isValidRealtimeDatabaseKey(normalizedValue)) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must be a valid '
        'Realtime Database key.',
      );
    }

    return normalizedValue;
  }
}
