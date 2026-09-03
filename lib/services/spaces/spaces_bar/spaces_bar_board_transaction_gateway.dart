import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/spaces_bar_board.dart';
import '../../../domain/models/spaces_bar_message.dart';
import '../../../domain/models/spaces_bar_publication_receipt.dart';
import 'spaces_bar_board_mapper.dart';

abstract interface class SpacesBarBoardTransactionContext {
  Future<Map<String, dynamic>?> readBoard();

  void setBoard(Map<String, dynamic> data);
}

abstract interface class SpacesBarBoardTransactionRunner {
  Future<T> run<T>(
    Future<T> Function(SpacesBarBoardTransactionContext context) action,
  );
}

final class SpacesBarBoardCapacityException implements Exception {
  const SpacesBarBoardCapacityException();

  @override
  String toString() {
    return 'SpacesBarBoardCapacityException: '
        'SpacesBar already contains three active messages.';
  }
}

final class SpacesBarBoardTransactionGateway {
  factory SpacesBarBoardTransactionGateway({
    required SpacesBarBoardTransactionRunner transactionRunner,
    DateTime Function()? clock,
  }) {
    return SpacesBarBoardTransactionGateway._(
      transactionRunner,
      clock ?? _utcNow,
    );
  }

  SpacesBarBoardTransactionGateway._(this._transactionRunner, this._clock);

  factory SpacesBarBoardTransactionGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    return SpacesBarBoardTransactionGateway(
      transactionRunner: _FirebaseSpacesBarBoardTransactionRunner(
        firestore ?? FirebaseFirestore.instance,
      ),
    );
  }

  final SpacesBarBoardTransactionRunner _transactionRunner;
  final DateTime Function() _clock;

  Future<SpacesBarPublicationReceipt> publish({
    required String text,
    required SpacesBarMessageLifetime lifetime,
    required String createdByUserId,
  }) {
    final normalizedText = _normalizeText(text);
    final normalizedCreatedByUserId = _normalizeId(
      createdByUserId,
      argumentName: 'createdByUserId',
    );

    return _transactionRunner.run((context) async {
      final now = _clock().toUtc();
      final persistedData = await context.readBoard();

      final board = persistedData == null
          ? SpacesBarBoard.empty()
          : SpacesBarBoardMapper.fromMap(persistedData);

      if (board == null) {
        throw StateError('SpacesBar board contains invalid data.');
      }

      final activeMessages = board.activeMessagesAt(now);

      if (activeMessages.length >= SpacesBarBoard.maxMessages) {
        throw const SpacesBarBoardCapacityException();
      }

      final nextRevision = board.revision + 1;
      final messageId = nextRevision.toString();

      if (activeMessages.any((message) => message.id == messageId)) {
        throw StateError(
          'SpacesBar board revision conflicts with an existing message id.',
        );
      }

      final newMessage = SpacesBarMessage.tryCreate(
        id: messageId,
        text: normalizedText,
        lifetime: lifetime,
        createdByUserId: normalizedCreatedByUserId,
        createdAt: now,
      );

      if (newMessage == null) {
        throw StateError('Unable to create a valid SpacesBar message.');
      }

      final nextBoard = SpacesBarBoard.tryCreate(
        revision: nextRevision,
        messages: <SpacesBarMessage>[...activeMessages, newMessage],
      );

      if (nextBoard == null) {
        throw StateError('Unable to create the next SpacesBar board state.');
      }

      context.setBoard(
        SpacesBarBoardMapper.toWriteMap(
          nextBoard,
          serverCreatedAtMessageId: messageId,
        ),
      );

      return SpacesBarPublicationReceipt(
        messageId: messageId,
        revision: nextRevision,
      );
    });
  }

  Future<bool> deleteMessage({required String messageId}) {
    final normalizedMessageId = _normalizeId(
      messageId,
      argumentName: 'messageId',
    );

    return _transactionRunner.run((context) async {
      final now = _clock().toUtc();
      final persistedData = await context.readBoard();

      if (persistedData == null) {
        return false;
      }

      final board = SpacesBarBoardMapper.fromMap(persistedData);

      if (board == null) {
        throw StateError('SpacesBar board contains invalid data.');
      }

      final containsMessage = board.messages.any(
        (message) => message.id == normalizedMessageId,
      );

      if (!containsMessage) {
        return false;
      }

      final remainingMessages = board
          .activeMessagesAt(now)
          .where((message) => message.id != normalizedMessageId)
          .toList();

      final nextBoard = SpacesBarBoard.tryCreate(
        revision: board.revision + 1,
        messages: remainingMessages,
      );

      if (nextBoard == null) {
        throw StateError('Unable to create the next SpacesBar board state.');
      }

      context.setBoard(SpacesBarBoardMapper.toWriteMap(nextBoard));

      return true;
    });
  }

  static String _normalizeText(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'text', 'Text must not be empty.');
    }

    if (normalized.length > SpacesBarMessage.maxTextLength) {
      throw ArgumentError.value(
        value,
        'text',
        'Text must not exceed '
            '${SpacesBarMessage.maxTextLength} characters.',
      );
    }

    return normalized;
  }

  static String _normalizeId(String value, {required String argumentName}) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must be non-empty '
        'and must not contain slashes.',
      );
    }

    return normalized;
  }

  static DateTime _utcNow() {
    return DateTime.now().toUtc();
  }
}

final class _FirebaseSpacesBarBoardTransactionRunner
    implements SpacesBarBoardTransactionRunner {
  _FirebaseSpacesBarBoardTransactionRunner(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<T> run<T>(
    Future<T> Function(SpacesBarBoardTransactionContext context) action,
  ) {
    final boardReference = _firestore.collection('spaces').doc('spacesBar');

    return _firestore.runTransaction((transaction) {
      final context = _FirebaseSpacesBarBoardTransactionContext(
        transaction,
        boardReference,
      );

      return action(context);
    });
  }
}

final class _FirebaseSpacesBarBoardTransactionContext
    implements SpacesBarBoardTransactionContext {
  _FirebaseSpacesBarBoardTransactionContext(
    this._transaction,
    this._boardReference,
  );

  final Transaction _transaction;
  final DocumentReference<Map<String, dynamic>> _boardReference;

  @override
  Future<Map<String, dynamic>?> readBoard() async {
    final snapshot = await _transaction.get(_boardReference);

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  @override
  void setBoard(Map<String, dynamic> data) {
    _transaction.set(_boardReference, data);
  }
}
