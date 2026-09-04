import 'package:epistola/domain/models/spaces_bar_board.dart';
import 'package:epistola/domain/models/spaces_bar_message.dart';

import 'spaces_bar_visible_messages_resolver.dart';

typedef SpacesBarBoardLoader = Future<SpacesBarBoard> Function();

typedef SpacesBarBoardWatcher = Stream<SpacesBarBoard> Function();

typedef SpacesBarHiddenMessageIdsLoader =
    Future<Set<String>> Function({required String userId});

typedef SpacesBarMessageHider =
    Future<void> Function({required String userId, required String messageId});

final class SpacesBarPresentationState {
  const SpacesBarPresentationState({
    required this.board,
    required this.hiddenMessageIds,
    required this.activeMessages,
    required this.visibleMessages,
  });

  final SpacesBarBoard board;
  final Set<String> hiddenMessageIds;
  final List<SpacesBarMessage> activeMessages;
  final List<SpacesBarMessage> visibleMessages;

  int get activeMessageCount => activeMessages.length;

  bool get hasVisibleMessages => visibleMessages.isNotEmpty;
}

final class SpacesBarPresentationService {
  factory SpacesBarPresentationService({
    required SpacesBarBoardLoader boardLoader,
    SpacesBarBoardWatcher? boardWatcher,
    required SpacesBarHiddenMessageIdsLoader hiddenMessageIdsLoader,
    required SpacesBarMessageHider messageHider,
    SpacesBarVisibleMessagesResolver resolver =
        const SpacesBarVisibleMessagesResolver(),
    DateTime Function()? clock,
  }) {
    return SpacesBarPresentationService._(
      boardLoader,
      boardWatcher,
      hiddenMessageIdsLoader,
      messageHider,
      resolver,
      clock ?? _utcNow,
    );
  }

  SpacesBarPresentationService._(
    this._boardLoader,
    this._boardWatcher,
    this._hiddenMessageIdsLoader,
    this._messageHider,
    this._resolver,
    this._clock,
  );

  final SpacesBarBoardLoader _boardLoader;
  final SpacesBarBoardWatcher? _boardWatcher;
  final SpacesBarHiddenMessageIdsLoader _hiddenMessageIdsLoader;
  final SpacesBarMessageHider _messageHider;
  final SpacesBarVisibleMessagesResolver _resolver;
  final DateTime Function() _clock;

  Future<SpacesBarPresentationState> load({required String userId}) async {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');

    final board = await _boardLoader();
    final hiddenMessageIds = await _hiddenMessageIdsLoader(
      userId: normalizedUserId,
    );

    return _resolve(board: board, hiddenMessageIds: hiddenMessageIds);
  }

  Stream<SpacesBarPresentationState> watch({required String userId}) async* {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');

    final boardWatcher = _boardWatcher;

    if (boardWatcher == null) {
      throw StateError('SpacesBar board watcher is not configured.');
    }

    await for (final board in boardWatcher()) {
      final hiddenMessageIds = await _hiddenMessageIdsLoader(
        userId: normalizedUserId,
      );

      yield _resolve(board: board, hiddenMessageIds: hiddenMessageIds);
    }
  }

  Future<SpacesBarPresentationState> hideMessage({
    required String userId,
    required String messageId,
    required SpacesBarPresentationState currentState,
  }) async {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');
    final normalizedMessageId = _normalizeRequired(
      messageId,
      argumentName: 'messageId',
    );

    await _messageHider(
      userId: normalizedUserId,
      messageId: normalizedMessageId,
    );

    final hiddenMessageIds = <String>{
      ...currentState.hiddenMessageIds,
      normalizedMessageId,
    };

    return _resolve(
      board: currentState.board,
      hiddenMessageIds: hiddenMessageIds,
    );
  }

  SpacesBarPresentationState _resolve({
    required SpacesBarBoard board,
    required Set<String> hiddenMessageIds,
  }) {
    final now = _clock().toUtc();

    return SpacesBarPresentationState(
      board: board,
      hiddenMessageIds: Set<String>.unmodifiable(hiddenMessageIds),
      activeMessages: List<SpacesBarMessage>.unmodifiable(
        board.activeMessagesAt(now),
      ),
      visibleMessages: _resolver.resolve(
        board: board,
        hiddenMessageIds: hiddenMessageIds,
        now: now,
      ),
    );
  }

  static String _normalizeRequired(
    String value, {
    required String argumentName,
  }) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, argumentName, 'must not be empty');
    }

    return normalized;
  }

  static DateTime _utcNow() {
    return DateTime.now().toUtc();
  }
}
