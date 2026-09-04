import 'dart:async';

import 'package:epistola/domain/models/spaces_bar_board.dart';
import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/domain/models/substitution_confirmed_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';

import 'spaces_bar_presentation_item.dart';
import 'spaces_bar_substitution_call_resolver.dart';
import 'spaces_bar_visible_messages_resolver.dart';

typedef SpacesBarBoardLoader = Future<SpacesBarBoard> Function();

typedef SpacesBarBoardWatcher = Stream<SpacesBarBoard> Function();

typedef SpacesBarHiddenMessageIdsLoader =
    Future<Set<String>> Function({required String userId});

typedef SpacesBarMessageHider =
    Future<void> Function({required String userId, required String messageId});

typedef SpacesBarConfirmedCallsLoader =
    Future<List<SubstitutionConfirmedCall>> Function({required String userId});

typedef SpacesBarConfirmedCallsWatcher =
    Stream<List<SubstitutionConfirmedCall>> Function({required String userId});

typedef SpacesBarHiddenSubstitutionCallIdsLoader =
    Future<Set<String>> Function({required String userId});

typedef SpacesBarSubstitutionCallHider =
    Future<void> Function({required String userId, required String callId});

typedef SpacesBarSubstitutionCallTextBuilder =
    String Function(SubstitutionConfirmedCall call);

final class SpacesBarPresentationState {
  const SpacesBarPresentationState({
    required this.board,
    required this.hiddenMessageIds,
    required this.activeMessages,
    required this.visibleMessages,
    required this.confirmedCalls,
    required this.hiddenSubstitutionCallIds,
    required this.activeSubstitutionCalls,
    required this.visibleSubstitutionCalls,
    required this.presentationItems,
    required this.nextSubstitutionExpiryAtLocal,
  });

  /// Исходная general-board модель.
  final SpacesBarBoard board;

  /// Local hide только обычных manager announcements.
  final Set<String> hiddenMessageIds;

  /// Активные обычные сообщения.
  ///
  /// Именно этот список используется редактором и лимитом 3/3.
  final List<SpacesBarMessage> activeMessages;

  final List<SpacesBarMessage> visibleMessages;

  /// Полная загруженная история confirmed calls текущего пользователя.
  ///
  /// Здесь могут находиться уже истёкшие для SpacesBar вызовы:
  /// они нужны позже для read-only истории в Chats.
  final List<SubstitutionConfirmedCall> confirmedCalls;

  /// Отдельный local-hide namespace персональных вызовов.
  final Set<String> hiddenSubstitutionCallIds;

  /// Подтверждённые вызовы, смена которых ещё не началась.
  final List<SubstitutionConfirmedCall> activeSubstitutionCalls;

  /// Активные вызовы без локально скрытых.
  final List<SubstitutionConfirmedCall> visibleSubstitutionCalls;

  /// Единый presentation-список будущей карусели.
  final List<SpacesBarPresentationItem> presentationItems;

  /// Ближайшее 08:00 / 20:00 local time.
  ///
  /// На следующем этапе используется для локального expiry Timer.
  final DateTime? nextSubstitutionExpiryAtLocal;

  int get activeMessageCount => activeMessages.length;

  int get activeSubstitutionCallCount => activeSubstitutionCalls.length;

  bool get hasVisibleMessages => visibleMessages.isNotEmpty;

  bool get hasVisibleSubstitutionCalls => visibleSubstitutionCalls.isNotEmpty;

  bool get hasPresentationItems => presentationItems.isNotEmpty;
}

final class SpacesBarPresentationService {
  factory SpacesBarPresentationService({
    required SpacesBarBoardLoader boardLoader,
    SpacesBarBoardWatcher? boardWatcher,
    required SpacesBarHiddenMessageIdsLoader hiddenMessageIdsLoader,
    required SpacesBarMessageHider messageHider,
    SpacesBarConfirmedCallsLoader? confirmedCallsLoader,
    SpacesBarConfirmedCallsWatcher? confirmedCallsWatcher,
    SpacesBarHiddenSubstitutionCallIdsLoader? hiddenSubstitutionCallIdsLoader,
    SpacesBarSubstitutionCallHider? substitutionCallHider,
    SpacesBarVisibleMessagesResolver resolver =
        const SpacesBarVisibleMessagesResolver(),
    SpacesBarSubstitutionCallResolver substitutionCallResolver =
        const SpacesBarSubstitutionCallResolver(),
    SpacesBarSubstitutionCallTextBuilder? substitutionCallTextBuilder,
    DateTime Function()? clock,
    DateTime Function()? localClock,
  }) {
    return SpacesBarPresentationService._(
      boardLoader,
      boardWatcher,
      hiddenMessageIdsLoader,
      messageHider,
      confirmedCallsLoader,
      confirmedCallsWatcher,
      hiddenSubstitutionCallIdsLoader,
      substitutionCallHider,
      resolver,
      substitutionCallResolver,
      substitutionCallTextBuilder ?? _defaultSubstitutionCallText,
      clock ?? _utcNow,
      localClock ?? _localNow,
    );
  }

  SpacesBarPresentationService._(
    this._boardLoader,
    this._boardWatcher,
    this._hiddenMessageIdsLoader,
    this._messageHider,
    this._confirmedCallsLoader,
    this._confirmedCallsWatcher,
    this._hiddenSubstitutionCallIdsLoader,
    this._substitutionCallHider,
    this._resolver,
    this._substitutionCallResolver,
    this._substitutionCallTextBuilder,
    this._clock,
    this._localClock,
  );

  final SpacesBarBoardLoader _boardLoader;
  final SpacesBarBoardWatcher? _boardWatcher;

  final SpacesBarHiddenMessageIdsLoader _hiddenMessageIdsLoader;

  final SpacesBarMessageHider _messageHider;

  final SpacesBarConfirmedCallsLoader? _confirmedCallsLoader;

  final SpacesBarConfirmedCallsWatcher? _confirmedCallsWatcher;

  final SpacesBarHiddenSubstitutionCallIdsLoader?
  _hiddenSubstitutionCallIdsLoader;

  final SpacesBarSubstitutionCallHider? _substitutionCallHider;

  final SpacesBarVisibleMessagesResolver _resolver;

  final SpacesBarSubstitutionCallResolver _substitutionCallResolver;

  final SpacesBarSubstitutionCallTextBuilder _substitutionCallTextBuilder;

  final DateTime Function() _clock;
  final DateTime Function() _localClock;

  Future<SpacesBarPresentationState> load({required String userId}) async {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');

    final board = await _boardLoader();

    final hiddenMessageIds = await _hiddenMessageIdsLoader(
      userId: normalizedUserId,
    );

    final confirmedCallsLoader = _confirmedCallsLoader;

    final confirmedCalls = confirmedCallsLoader == null
        ? const <SubstitutionConfirmedCall>[]
        : await confirmedCallsLoader(userId: normalizedUserId);

    final hiddenSubstitutionCallIdsLoader = _hiddenSubstitutionCallIdsLoader;

    final hiddenSubstitutionCallIds = hiddenSubstitutionCallIdsLoader == null
        ? <String>{}
        : await hiddenSubstitutionCallIdsLoader(userId: normalizedUserId);

    return _resolve(
      board: board,
      hiddenMessageIds: hiddenMessageIds,
      confirmedCalls: confirmedCalls,
      hiddenSubstitutionCallIds: hiddenSubstitutionCallIds,
    );
  }

  Stream<SpacesBarPresentationState> watch({required String userId}) {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');

    final boardWatcher = _boardWatcher;

    if (boardWatcher == null) {
      throw StateError('SpacesBar board watcher is not configured.');
    }

    final confirmedCallsWatcher = _confirmedCallsWatcher;

    late final StreamController<SpacesBarPresentationState> controller;

    StreamSubscription<SpacesBarBoard>? boardSubscription;

    StreamSubscription<List<SubstitutionConfirmedCall>>?
    confirmedCallsSubscription;

    SpacesBarBoard? latestBoard;

    var latestConfirmedCalls = const <SubstitutionConfirmedCall>[];

    var hasBoard = false;
    var hasConfirmedCalls = confirmedCallsWatcher == null;

    var cancelled = false;

    Future<void> pendingResolution = Future<void>.value();

    Future<void> resolveSnapshot({
      required SpacesBarBoard board,
      required List<SubstitutionConfirmedCall> confirmedCalls,
    }) async {
      if (cancelled) {
        return;
      }

      try {
        final hiddenMessageIds = await _hiddenMessageIdsLoader(
          userId: normalizedUserId,
        );

        final hiddenSubstitutionCallIdsLoader =
            _hiddenSubstitutionCallIdsLoader;

        final hiddenSubstitutionCallIds =
            hiddenSubstitutionCallIdsLoader == null
            ? <String>{}
            : await hiddenSubstitutionCallIdsLoader(userId: normalizedUserId);

        if (cancelled) {
          return;
        }

        controller.add(
          _resolve(
            board: board,
            hiddenMessageIds: hiddenMessageIds,
            confirmedCalls: confirmedCalls,
            hiddenSubstitutionCallIds: hiddenSubstitutionCallIds,
          ),
        );
      } catch (error, stackTrace) {
        if (!cancelled) {
          controller.addError(error, stackTrace);
        }
      }
    }

    void scheduleResolution() {
      if (!hasBoard || !hasConfirmedCalls) {
        return;
      }

      final boardSnapshot = latestBoard!;

      final confirmedCallsSnapshot =
          List<SubstitutionConfirmedCall>.unmodifiable(latestConfirmedCalls);

      pendingResolution = pendingResolution.then(
        (_) => resolveSnapshot(
          board: boardSnapshot,
          confirmedCalls: confirmedCallsSnapshot,
        ),
      );
    }

    void addStreamError(Object error, StackTrace stackTrace) {
      if (!cancelled) {
        controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<SpacesBarPresentationState>(
      onListen: () {
        boardSubscription = boardWatcher().listen((board) {
          latestBoard = board;
          hasBoard = true;

          scheduleResolution();
        }, onError: addStreamError);

        if (confirmedCallsWatcher != null) {
          confirmedCallsSubscription =
              confirmedCallsWatcher(userId: normalizedUserId).listen((calls) {
                latestConfirmedCalls = calls;
                hasConfirmedCalls = true;

                scheduleResolution();
              }, onError: addStreamError);
        }
      },
      onCancel: () async {
        cancelled = true;

        await boardSubscription?.cancel();
        await confirmedCallsSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  SpacesBarPresentationState refreshForCurrentTime({
    required SpacesBarPresentationState currentState,
  }) {
    return _resolve(
      board: currentState.board,
      hiddenMessageIds: currentState.hiddenMessageIds,
      confirmedCalls: currentState.confirmedCalls,
      hiddenSubstitutionCallIds: currentState.hiddenSubstitutionCallIds,
    );
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
      confirmedCalls: currentState.confirmedCalls,
      hiddenSubstitutionCallIds: currentState.hiddenSubstitutionCallIds,
    );
  }

  Future<SpacesBarPresentationState> hideSubstitutionCall({
    required String userId,
    required String callId,
    required SpacesBarPresentationState currentState,
  }) async {
    final normalizedUserId = _normalizeRequired(userId, argumentName: 'userId');

    final normalizedCallId = _normalizeRequired(callId, argumentName: 'callId');

    final substitutionCallHider = _substitutionCallHider;

    if (substitutionCallHider == null) {
      throw StateError(
        'SpacesBar substitution call hider '
        'is not configured.',
      );
    }

    await substitutionCallHider(
      userId: normalizedUserId,
      callId: normalizedCallId,
    );

    final hiddenSubstitutionCallIds = <String>{
      ...currentState.hiddenSubstitutionCallIds,
      normalizedCallId,
    };

    return _resolve(
      board: currentState.board,
      hiddenMessageIds: currentState.hiddenMessageIds,
      confirmedCalls: currentState.confirmedCalls,
      hiddenSubstitutionCallIds: hiddenSubstitutionCallIds,
    );
  }

  SpacesBarPresentationState _resolve({
    required SpacesBarBoard board,
    required Set<String> hiddenMessageIds,
    required List<SubstitutionConfirmedCall> confirmedCalls,
    required Set<String> hiddenSubstitutionCallIds,
  }) {
    final nowUtc = _clock().toUtc();
    final nowLocal = _localClock();

    final activeMessages = board.activeMessagesAt(nowUtc);

    final visibleMessages = _resolver.resolve(
      board: board,
      hiddenMessageIds: hiddenMessageIds,
      now: nowUtc,
    );

    final substitutionResolution = _substitutionCallResolver.resolve(
      calls: confirmedCalls,
      hiddenCallIds: hiddenSubstitutionCallIds,
      nowLocal: nowLocal,
    );

    final presentationItems = <SpacesBarPresentationItem>[
      ...visibleMessages.map(
        (message) => SpacesBarPresentationItem.general(message: message),
      ),
      ...substitutionResolution.visibleCalls.map(
        (call) => SpacesBarPresentationItem.substitution(
          call: call,
          text: _substitutionCallTextBuilder(call),
        ),
      ),
    ];

    presentationItems.sort((first, second) {
      final publishedComparison = second.publishedAt.compareTo(
        first.publishedAt,
      );

      if (publishedComparison != 0) {
        return publishedComparison;
      }

      return first.presentationId.compareTo(second.presentationId);
    });

    return SpacesBarPresentationState(
      board: board,
      hiddenMessageIds: Set<String>.unmodifiable(hiddenMessageIds),
      activeMessages: List<SpacesBarMessage>.unmodifiable(activeMessages),
      visibleMessages: List<SpacesBarMessage>.unmodifiable(visibleMessages),
      confirmedCalls: List<SubstitutionConfirmedCall>.unmodifiable(
        confirmedCalls,
      ),
      hiddenSubstitutionCallIds: Set<String>.unmodifiable(
        hiddenSubstitutionCallIds,
      ),
      activeSubstitutionCalls: substitutionResolution.activeCalls,
      visibleSubstitutionCalls: substitutionResolution.visibleCalls,
      presentationItems: List<SpacesBarPresentationItem>.unmodifiable(
        presentationItems,
      ),
      nextSubstitutionExpiryAtLocal:
          substitutionResolution.nextVisibleExpiryAtLocal,
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

  static DateTime _localNow() {
    return DateTime.now();
  }
}

String _defaultSubstitutionCallText(SubstitutionConfirmedCall call) {
  final shift = call.shift;

  final day = shift.day.toString().padLeft(2, '0');

  final month = shift.month.toString().padLeft(2, '0');

  final hour = shift.startHour.toString().padLeft(2, '0');

  final shiftLabel = switch (shift.kind) {
    SubstitutionShiftKind.day => 'дневную',
    SubstitutionShiftKind.night => 'ночную',
  };

  return 'Вы вызваны на $shiftLabel смену '
      '$day.$month.${shift.year} в $hour:00';
}
