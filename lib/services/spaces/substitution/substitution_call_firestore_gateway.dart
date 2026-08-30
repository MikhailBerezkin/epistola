import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_call_receipt.dart';
import 'substitution_pending_call_mapper.dart';
import '../../../domain/models/substitution_shift.dart';

abstract interface class SubstitutionCallTransactionContext {
  Future<Map<String, dynamic>?> readModule();

  Future<Map<String, dynamic>?> readParticipant({required String userId});
  Future<Map<String, dynamic>?> readPendingCall({required String callId});

  void updateModule(Map<String, dynamic> data);

  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  });

  void createPendingCall({
    required String callId,
    required Map<String, dynamic> data,
  });
  void deletePendingCall({required String callId});

  void clearLastCall();
}

abstract interface class SubstitutionCallTransactionRunner {
  Future<T> run<T>(
    Future<T> Function(SubstitutionCallTransactionContext context) action,
  );
}

final class SubstitutionCallFirestoreGateway {
  SubstitutionCallFirestoreGateway(this._transactionRunner);

  factory SubstitutionCallFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    return SubstitutionCallFirestoreGateway(
      _FirebaseSubstitutionCallTransactionRunner(
        firestore ?? FirebaseFirestore.instance,
      ),
    );
  }

  final SubstitutionCallTransactionRunner _transactionRunner;

  static const String nextRotationOrderField = 'nextRotationOrder';
  static const String revisionField = 'revision';
  static const String lastCallField = 'lastCall';

  static const String rotationOrderField = 'rotationOrder';
  static const String statusField = 'status';

  static const String lastCallUserIdField = 'userId';
  static const String lastCallPreviousRotationOrderField =
      'previousRotationOrder';
  static const String lastCallRevisionField = 'revision';

  Future<SubstitutionCallReceipt> callParticipant({
    required String userId,
    required String calledByUserId,
    required SubstitutionShift shift,
  }) {
    final normalizedUserId = _normalizeUserId(userId);
    final normalizedCalledByUserId = _normalizeUserId(calledByUserId);

    return _transactionRunner.run((context) async {
      final moduleData = await context.readModule();

      if (moduleData == null) {
        throw StateError('Substitution module document does not exist.');
      }

      final participantData = await context.readParticipant(
        userId: normalizedUserId,
      );

      if (participantData == null) {
        throw StateError('Participant is not in the substitution rotation.');
      }

      final nextRotationOrder = _readNonNegativeInt(
        moduleData,
        nextRotationOrderField,
        documentName: 'substitution module',
      );

      final revisionValue = moduleData[revisionField];

      final currentRevision = revisionValue == null
          ? 0
          : _readNonNegativeInt(
              moduleData,
              revisionField,
              documentName: 'substitution module',
            );

      final previousRotationOrder = _readNonNegativeInt(
        participantData,
        rotationOrderField,
        documentName: 'substitution participant',
      );

      final status = participantData[statusField];

      if (status != 'active') {
        throw StateError('Only an active participant can be called.');
      }

      final nextRevision = currentRevision + 1;
      final callId = nextRevision.toString();

      context.createPendingCall(
        callId: callId,
        data: SubstitutionPendingCallMapper.toCreateMap(
          callId: callId,
          shift: shift,
          userId: normalizedUserId,
          revision: nextRevision,
          calledByUserId: normalizedCalledByUserId,
        ),
      );

      context.updateParticipant(
        userId: normalizedUserId,
        data: <String, dynamic>{rotationOrderField: nextRotationOrder},
      );

      context.updateModule(<String, dynamic>{
        nextRotationOrderField: nextRotationOrder + 1,
        revisionField: nextRevision,
        lastCallField: <String, dynamic>{
          lastCallUserIdField: normalizedUserId,
          lastCallPreviousRotationOrderField: previousRotationOrder,
          lastCallRevisionField: nextRevision,
        },
      });

      return SubstitutionCallReceipt(
        userId: normalizedUserId,
        revision: nextRevision,
      );
    });
  }

  Future<bool> undoLastCall({required SubstitutionCallReceipt receipt}) {
    final normalizedUserId = _normalizeUserId(receipt.userId);

    if (receipt.revision < 1) {
      throw ArgumentError.value(
        receipt.revision,
        'receipt.revision',
        'revision must be greater than zero.',
      );
    }

    return _transactionRunner.run((context) async {
      final moduleData = await context.readModule();

      if (moduleData == null) {
        return false;
      }

      final lastCallRaw = moduleData[lastCallField];

      if (lastCallRaw is! Map) {
        return false;
      }

      final lastCall = Map<String, dynamic>.from(lastCallRaw);

      final lastCallUserId = lastCall[lastCallUserIdField];
      final lastCallRevision = lastCall[lastCallRevisionField];
      final previousRotationOrder =
          lastCall[lastCallPreviousRotationOrderField];

      if (lastCallUserId is! String ||
          lastCallRevision is! int ||
          previousRotationOrder is! int) {
        return false;
      }

      if (lastCallUserId != normalizedUserId ||
          lastCallRevision != receipt.revision) {
        return false;
      }

      if (previousRotationOrder < 0) {
        return false;
      }

      final pendingCallData = await context.readPendingCall(
        callId: receipt.callId,
      );

      if (pendingCallData == null) {
        return false;
      }

      final pendingCall = SubstitutionPendingCallMapper.fromMap(
        pendingCallData,
      );

      if (pendingCall == null) {
        throw StateError(
          'Substitution pending call document contains invalid data.',
        );
      }

      if (pendingCall.callId != receipt.callId ||
          pendingCall.userId != normalizedUserId ||
          pendingCall.revision != receipt.revision) {
        return false;
      }

      final participantData = await context.readParticipant(
        userId: normalizedUserId,
      );

      if (participantData == null) {
        return false;
      }

      context.updateParticipant(
        userId: normalizedUserId,
        data: <String, dynamic>{rotationOrderField: previousRotationOrder},
      );

      context.clearLastCall();
      context.deletePendingCall(callId: receipt.callId);

      return true;
    });
  }

  static int _readNonNegativeInt(
    Map<String, dynamic> data,
    String field, {
    required String documentName,
  }) {
    final value = data[field];

    if (value is! int || value < 0) {
      throw StateError(
        '$documentName field "$field" must be a non-negative integer.',
      );
    }

    return value;
  }

  static String _normalizeUserId(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(
        value,
        'userId',
        'userId must be non-empty and must not contain slashes.',
      );
    }

    return normalized;
  }
}

final class _FirebaseSubstitutionCallTransactionRunner
    implements SubstitutionCallTransactionRunner {
  _FirebaseSubstitutionCallTransactionRunner(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<T> run<T>(
    Future<T> Function(SubstitutionCallTransactionContext context) action,
  ) {
    final moduleReference = _firestore.collection('spaces').doc('substitution');

    return _firestore.runTransaction((transaction) {
      final context = _FirebaseSubstitutionCallTransactionContext(
        transaction,
        moduleReference,
      );

      return action(context);
    });
  }
}

final class _FirebaseSubstitutionCallTransactionContext
    implements SubstitutionCallTransactionContext {
  _FirebaseSubstitutionCallTransactionContext(
    this._transaction,
    this._moduleReference,
  );

  final Transaction _transaction;
  final DocumentReference<Map<String, dynamic>> _moduleReference;

  DocumentReference<Map<String, dynamic>> _participantReference(String userId) {
    return _moduleReference.collection('participants').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> _pendingCallReference(String callId) {
    return _moduleReference.collection('pendingCalls').doc(callId);
  }

  @override
  Future<Map<String, dynamic>?> readModule() async {
    final snapshot = await _transaction.get(_moduleReference);

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  @override
  Future<Map<String, dynamic>?> readParticipant({
    required String userId,
  }) async {
    final snapshot = await _transaction.get(_participantReference(userId));

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  @override
  Future<Map<String, dynamic>?> readPendingCall({
    required String callId,
  }) async {
    final snapshot = await _transaction.get(_pendingCallReference(callId));

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  @override
  void updateModule(Map<String, dynamic> data) {
    _transaction.update(_moduleReference, data);
  }

  @override
  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    _transaction.update(_participantReference(userId), data);
  }

  @override
  void createPendingCall({
    required String callId,
    required Map<String, dynamic> data,
  }) {
    _transaction.set(_pendingCallReference(callId), data);
  }

  @override
  void deletePendingCall({required String callId}) {
    _transaction.delete(_pendingCallReference(callId));
  }

  @override
  void clearLastCall() {
    _transaction.update(_moduleReference, <String, dynamic>{
      SubstitutionCallFirestoreGateway.lastCallField: FieldValue.delete(),
    });
  }
}
