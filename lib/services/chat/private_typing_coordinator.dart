import 'dart:async';

typedef PrivateTypingAction = Future<void> Function();

typedef PrivateTypingCoordinatorErrorHandler =
    void Function(Object error, StackTrace stackTrace);

final class PrivateTypingCoordinator {
  factory PrivateTypingCoordinator({
    required PrivateTypingAction startTyping,
    required PrivateTypingAction stopTyping,
    PrivateTypingCoordinatorErrorHandler? onError,
    Duration startDelay = const Duration(milliseconds: 450),
    Duration inactivityDelay = const Duration(seconds: 4),
    Duration heartbeatDelay = const Duration(seconds: 3),
  }) {
    if (startDelay.isNegative) {
      throw ArgumentError.value(
        startDelay,
        'startDelay',
        'Typing start delay must not be negative.',
      );
    }

    if (inactivityDelay <= Duration.zero) {
      throw ArgumentError.value(
        inactivityDelay,
        'inactivityDelay',
        'Typing inactivity delay must be positive.',
      );
    }

    if (heartbeatDelay <= Duration.zero) {
      throw ArgumentError.value(
        heartbeatDelay,
        'heartbeatDelay',
        'Typing heartbeat delay must be positive.',
      );
    }

    return PrivateTypingCoordinator._(
      startTyping,
      stopTyping,
      onError,
      startDelay,
      inactivityDelay,
      heartbeatDelay,
    );
  }

  PrivateTypingCoordinator._(
    this._startTyping,
    this._stopTyping,
    this._onError,
    this._startDelay,
    this._inactivityDelay,
    this._heartbeatDelay,
  );

  final PrivateTypingAction _startTyping;
  final PrivateTypingAction _stopTyping;

  final PrivateTypingCoordinatorErrorHandler? _onError;

  final Duration _startDelay;
  final Duration _inactivityDelay;
  final Duration _heartbeatDelay;

  Timer? _startTimer;
  Timer? _inactivityTimer;
  Timer? _heartbeatTimer;

  Future<void> _operationQueue = Future<void>.value();

  bool _desiredTyping = false;
  bool _isTypingPublished = false;
  bool _isDisposed = false;

  void handleTextChanged(String text) {
    if (_isDisposed) {
      return;
    }

    if (text.isEmpty) {
      _desiredTyping = false;

      _cancelStartTimer();
      _cancelInactivityTimer();
      _cancelHeartbeatTimer();

      unawaited(_enqueueStop(force: false));

      return;
    }

    _desiredTyping = true;

    _restartInactivityTimer();

    if (_isTypingPublished) {
      _scheduleHeartbeatIfNeeded();
    } else {
      _scheduleStartIfNeeded();
    }
  }

  Future<void> stopNow() {
    if (_isDisposed) {
      return Future<void>.value();
    }

    _desiredTyping = false;

    _cancelStartTimer();
    _cancelInactivityTimer();
    _cancelHeartbeatTimer();

    return _enqueueStop(force: true);
  }

  void _scheduleStartIfNeeded() {
    if (_isDisposed ||
        !_desiredTyping ||
        _isTypingPublished ||
        _startTimer != null) {
      return;
    }

    _startTimer = Timer(_startDelay, () {
      _startTimer = null;

      unawaited(_enqueueStart());
    });
  }

  void _restartInactivityTimer() {
    _cancelInactivityTimer();

    _inactivityTimer = Timer(_inactivityDelay, () {
      _inactivityTimer = null;
      _desiredTyping = false;

      _cancelStartTimer();
      _cancelHeartbeatTimer();

      unawaited(_enqueueStop(force: false));
    });
  }

  void _scheduleHeartbeatIfNeeded() {
    if (_isDisposed ||
        !_desiredTyping ||
        !_isTypingPublished ||
        _heartbeatTimer != null) {
      return;
    }

    _heartbeatTimer = Timer(_heartbeatDelay, () {
      _heartbeatTimer = null;

      unawaited(_enqueueHeartbeat());
    });
  }

  Future<void> _enqueueStart() {
    return _enqueueOperation(() async {
      if (_isDisposed || !_desiredTyping || _isTypingPublished) {
        return;
      }

      await _startTyping();

      _isTypingPublished = true;

      _scheduleHeartbeatIfNeeded();
    });
  }

  Future<void> _enqueueHeartbeat() {
    return _enqueueOperation(() async {
      if (_isDisposed || !_desiredTyping || !_isTypingPublished) {
        return;
      }

      try {
        await _startTyping();
      } finally {
        _scheduleHeartbeatIfNeeded();
      }
    });
  }

  Future<void> _enqueueStop({required bool force}) {
    return _enqueueOperation(() async {
      if (!force && _desiredTyping) {
        return;
      }

      _cancelHeartbeatTimer();

      if (!_isTypingPublished) {
        _scheduleStartIfNeeded();
        return;
      }

      await _stopTyping();

      _isTypingPublished = false;

      _scheduleStartIfNeeded();
    });
  }

  Future<void> _enqueueOperation(PrivateTypingAction operation) {
    final completer = Completer<void>();

    _operationQueue = _operationQueue.then((_) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        _onError?.call(error, stackTrace);
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    return completer.future;
  }

  void _cancelStartTimer() {
    _startTimer?.cancel();
    _startTimer = null;
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _cancelHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _desiredTyping = false;

    _cancelStartTimer();
    _cancelInactivityTimer();
    _cancelHeartbeatTimer();
  }
}
