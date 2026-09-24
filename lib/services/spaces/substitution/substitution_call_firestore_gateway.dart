import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_call_receipt.dart';
import 'substitution_pending_call_mapper.dart';
import 'substitution_shift_call_claim.dart';
import '../../../domain/models/substitution_shift.dart';
import '../../../domain/models/shift_cycle.dart';
import '../../../domain/models/vacation_period.dart';
import '../calendar/vacation_period_mapper.dart';
import 'substitution_call_eligibility_resolver.dart';

abstract interface class SubstitutionCallTransactionContext {
  Future<Map<String, dynamic>?> readModule();

  Future<Map<String, dynamic>?> readParticipant({required String userId});
  Future<Map<String, dynamic>?> readUser({required String userId});

  Future<Map<String, dynamic>?> readVacationPeriod({
    required String documentId,
  });
  Future<Map<String, dynamic>?> readPendingCall({required String callId});
  Future<Map<String, dynamic>?> readShiftClaim({required String claimId});

  void updateModule(Map<String, dynamic> data);

  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  });

  void createPendingCall({
    required String callId,
    required Map<String, dynamic> data,
  });

  void createShiftClaim({
    required String claimId,
    required Map<String, dynamic> data,
  });

  void deletePendingCall({required String callId});

  void deleteShiftClaim({required String claimId});

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
  static const SubstitutionCallEligibilityResolver _eligibilityResolver =
      SubstitutionCallEligibilityResolver();

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

      final shiftClaimId = SubstitutionShiftCallClaim.idFor(
        userId: normalizedUserId,
        shift: shift,
      );

      final existingShiftClaim = await context.readShiftClaim(
        claimId: shiftClaimId,
      );

      if (existingShiftClaim != null) {
        throw SubstitutionShiftAlreadyCalledException(
          userId: normalizedUserId,
          shift: shift,
        );
      }

      final userData = await context.readUser(userId: normalizedUserId);

      final crew = _readAssignedCrew(userData);

      final vacationPeriods = await _readVacationPeriods(
        context: context,
        userId: normalizedUserId,
      );

      final eligibility = _eligibilityResolver.resolve(
        userId: normalizedUserId,
        crew: crew,
        shift: shift,
        vacationPeriods: vacationPeriods,
      );

      if (!eligibility.isEligible) {
        throw SubstitutionCallUnavailableException(
          userId: normalizedUserId,
          shift: shift,
          reason: eligibility.reason!,
        );
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

      context.createShiftClaim(
        claimId: shiftClaimId,
        data: SubstitutionShiftCallClaim.toCreateMap(
          userId: normalizedUserId,
          callId: callId,
          calledByUserId: normalizedCalledByUserId,
          shift: shift,
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

      final shiftClaimId = SubstitutionShiftCallClaim.idFor(
        userId: normalizedUserId,
        shift: pendingCall.shift,
      );

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
      context.deleteShiftClaim(claimId: shiftClaimId);

      return true;
    });
  }

  static ShiftCrew? _readAssignedCrew(Map<String, dynamic>? userData) {
    final value = userData?['assignedCrew'];

    if (value is! int) {
      return null;
    }

    for (final crew in ShiftCrew.values) {
      if (crew.number == value) {
        return crew;
      }
    }

    return null;
  }

  static Future<List<VacationPeriod>> _readVacationPeriods({
    required SubstitutionCallTransactionContext context,
    required String userId,
  }) async {
    final periods = <VacationPeriod>[];

    for (var slot = 1; slot <= 6; slot += 1) {
      final documentId = '${userId}__$slot';

      final data = await context.readVacationPeriod(documentId: documentId);

      if (data == null) {
        continue;
      }

      final period = VacationPeriodMapper.fromMap(data);

      if (period == null ||
          period.userId != userId ||
          period.documentId != documentId) {
        throw StateError('Vacation period document contains invalid data.');
      }

      periods.add(period);
    }

    return periods;
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
        _firestore,
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
    this._firestore,
  );

  final Transaction _transaction;
  final DocumentReference<Map<String, dynamic>> _moduleReference;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _participantReference(String userId) {
    return _moduleReference.collection('participants').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> _userReference(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> _vacationPeriodReference(
    String documentId,
  ) {
    return _firestore
        .collection('spaces')
        .doc('calendar')
        .collection('vacationPeriods')
        .doc(documentId);
  }

  DocumentReference<Map<String, dynamic>> _pendingCallReference(String callId) {
    return _moduleReference.collection('pendingCalls').doc(callId);
  }

  DocumentReference<Map<String, dynamic>> _shiftClaimReference(String claimId) {
    return _moduleReference.collection('shiftClaims').doc(claimId);
  }

  @override
  Future<Map<String, dynamic>?> readShiftClaim({
    required String claimId,
  }) async {
    final snapshot = await _transaction.get(_shiftClaimReference(claimId));

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
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
  Future<Map<String, dynamic>?> readUser({required String userId}) async {
    final snapshot = await _transaction.get(_userReference(userId));

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  @override
  Future<Map<String, dynamic>?> readVacationPeriod({
    required String documentId,
  }) async {
    final snapshot = await _transaction.get(
      _vacationPeriodReference(documentId),
    );

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
  void createShiftClaim({
    required String claimId,
    required Map<String, dynamic> data,
  }) {
    _transaction.set(_shiftClaimReference(claimId), data);
  }

  @override
  void deletePendingCall({required String callId}) {
    _transaction.delete(_pendingCallReference(callId));
  }

  @override
  void deleteShiftClaim({required String claimId}) {
    _transaction.delete(_shiftClaimReference(claimId));
  }

  @override
  void clearLastCall() {
    _transaction.update(_moduleReference, <String, dynamic>{
      SubstitutionCallFirestoreGateway.lastCallField: FieldValue.delete(),
    });
  }
}
