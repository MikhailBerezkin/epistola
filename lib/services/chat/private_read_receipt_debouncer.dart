import 'dart:async';

import '../../domain/models/private_read_cursor.dart';

typedef PrivateReadReceiptCommit =
    Future<void> Function(PrivateReadCursor cursor);

typedef PrivateReadReceiptErrorHandler =
    void Function(Object error, StackTrace stackTrace);

final class PrivateReadReceiptDebouncer {
  factory PrivateReadReceiptDebouncer({
    required PrivateReadReceiptCommit commit,
    PrivateReadReceiptErrorHandler? onError,
    Duration delay = const Duration(milliseconds: 700),
  }) {
    if (delay.isNegative) {
      throw ArgumentError.value(
        delay,
        'delay',
        'Debounce delay must not be negative.',
      );
    }

    return PrivateReadReceiptDebouncer._(
      commit: commit,
      onError: onError,
      delay: delay,
    );
  }

  PrivateReadReceiptDebouncer._({
    required this._commit,
    required this._onError,
    required this._delay,
  });

  final PrivateReadReceiptCommit _commit;
  final PrivateReadReceiptErrorHandler? _onError;
  final Duration _delay;

  Timer? _timer;
  PrivateReadCursor? _pendingCursor;
  Future<void>? _activeWrite;

  bool _isDisposed = false;

  void schedule(PrivateReadCursor cursor) {
    if (_isDisposed) {
      return;
    }

    final pendingCursor = _pendingCursor;

    final pendingAlreadyCoversCursor =
        pendingCursor?.covers(
          messageId: cursor.messageId,
          messageCreatedAt: cursor.messageCreatedAt,
        ) ==
        true;

    if (pendingAlreadyCoversCursor) {
      return;
    }

    _pendingCursor = cursor;

    _restartTimer();
  }

  Future<void> flushNow() async {
    if (_isDisposed) {
      return;
    }

    _timer?.cancel();
    _timer = null;

    final activeWrite = _activeWrite;

    if (activeWrite != null) {
      await activeWrite;
    }

    if (_isDisposed || _pendingCursor == null) {
      return;
    }

    await _flushPending();
  }

  void _restartTimer() {
    _timer?.cancel();

    _timer = Timer(_delay, () {
      _timer = null;

      unawaited(_flushPending());
    });
  }

  Future<void> _flushPending() async {
    if (_isDisposed) {
      return;
    }

    final activeWrite = _activeWrite;

    if (activeWrite != null) {
      await activeWrite;

      if (!_isDisposed && _pendingCursor != null) {
        _restartTimer();
      }

      return;
    }

    final cursor = _pendingCursor;

    if (cursor == null) {
      return;
    }

    _pendingCursor = null;

    final write = _commit(cursor);
    _activeWrite = write;

    try {
      await write;
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    } finally {
      if (identical(_activeWrite, write)) {
        _activeWrite = null;
      }

      if (!_isDisposed && _pendingCursor != null) {
        _restartTimer();
      }
    }
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;

    _timer?.cancel();
    _timer = null;
    _pendingCursor = null;
  }
}
