import 'package:cloud_firestore/cloud_firestore.dart';

import 'substitution_confirmed_call_mapper.dart';
import 'substitution_pending_call_mapper.dart';
import 'substitution_statistics_accumulator.dart';
import 'substitution_statistics_mapper.dart';

abstract interface class SubstitutionCallFinalizationTransactionContext {
  Future<Map<String, dynamic>?> readPendingCall({required String callId});

  Future<Map<String, dynamic>?> readStatistics({required int year});

  void writeStatistics({required int year, required Map<String, dynamic> data});

  void writeConfirmedCall({
    required String callId,
    required Map<String, dynamic> data,
  });

  void deletePendingCall({required String callId});
}

abstract interface class SubstitutionCallFinalizationTransactionRunner {
  Future<T> run<T>(
    Future<T> Function(SubstitutionCallFinalizationTransactionContext context)
    action,
  );
}

final class SubstitutionCallFinalizationFirestoreGateway {
  SubstitutionCallFinalizationFirestoreGateway(this._transactionRunner);

  factory SubstitutionCallFinalizationFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    return SubstitutionCallFinalizationFirestoreGateway(
      _FirebaseSubstitutionCallFinalizationTransactionRunner(
        firestore ?? FirebaseFirestore.instance,
      ),
    );
  }

  final SubstitutionCallFinalizationTransactionRunner _transactionRunner;

  Future<bool> finalizePendingCall({required String callId}) {
    final normalizedCallId = _normalizeCallId(callId);

    return _transactionRunner.run((context) async {
      final pendingCallData = await context.readPendingCall(
        callId: normalizedCallId,
      );

      // Главная exactly-once защита:
      // если pendingCall уже удалён предыдущим успешным finalize,
      // повторный вызов ничего не делает.
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

      if (pendingCall.callId != normalizedCallId) {
        throw StateError(
          'Substitution pending call document id does not match callId.',
        );
      }

      final rawCalledAt =
          pendingCallData[SubstitutionPendingCallMapper.calledAtField];

      if (rawCalledAt is! Timestamp) {
        throw StateError(
          'Substitution pending call document contains invalid calledAt.',
        );
      }

      final statisticsYear = pendingCall.shift.statisticsYear;

      final statisticsData = await context.readStatistics(year: statisticsYear);

      final currentStatistics = statisticsData == null
          ? null
          : SubstitutionStatisticsMapper.fromMap(
              statisticsData,
              expectedYear: statisticsYear,
            );

      if (statisticsData != null && currentStatistics == null) {
        throw StateError(
          'Substitution statistics document contains invalid data.',
        );
      }

      final mutation = SubstitutionStatisticsAccumulator.applyConfirmedCall(
        current: currentStatistics,
        pendingCall: pendingCall,
      );

      final statisticsWriteData = SubstitutionStatisticsMapper.toWriteMap(
        year: mutation.year,
        monthCallCounts: mutation.monthCallCounts,
        monthShifts: mutation.monthShifts,
        yearCallCounts: mutation.yearCallCounts,
        finalizedCallId: mutation.finalizedCallId,
      );

      final confirmedCallWriteData =
          SubstitutionConfirmedCallMapper.toCreateMap(
            pendingCall: pendingCall,
            calledAt: rawCalledAt,
          );

      context.writeStatistics(year: statisticsYear, data: statisticsWriteData);

      context.writeConfirmedCall(
        callId: normalizedCallId,
        data: confirmedCallWriteData,
      );

      context.deletePendingCall(callId: normalizedCallId);

      return true;
    });
  }

  static String statisticsDocumentId(int year) {
    if (year < 1) {
      throw ArgumentError.value(
        year,
        'year',
        'year must be greater than zero.',
      );
    }

    return 'year_$year';
  }

  static String _normalizeCallId(String value) {
    final normalized = value.trim();
    final revision = int.tryParse(normalized);

    if (normalized != value ||
        revision == null ||
        revision < 1 ||
        revision.toString() != normalized) {
      throw ArgumentError.value(
        value,
        'callId',
        'callId must be a canonical positive integer string.',
      );
    }

    return normalized;
  }
}

final class _FirebaseSubstitutionCallFinalizationTransactionRunner
    implements SubstitutionCallFinalizationTransactionRunner {
  _FirebaseSubstitutionCallFinalizationTransactionRunner(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<T> run<T>(
    Future<T> Function(SubstitutionCallFinalizationTransactionContext context)
    action,
  ) {
    final moduleReference = _firestore.collection('spaces').doc('substitution');

    return _firestore.runTransaction((transaction) {
      final context = _FirebaseSubstitutionCallFinalizationTransactionContext(
        transaction,
        moduleReference,
      );

      return action(context);
    });
  }
}

final class _FirebaseSubstitutionCallFinalizationTransactionContext
    implements SubstitutionCallFinalizationTransactionContext {
  _FirebaseSubstitutionCallFinalizationTransactionContext(
    this._transaction,
    this._moduleReference,
  );

  final Transaction _transaction;
  final DocumentReference<Map<String, dynamic>> _moduleReference;

  DocumentReference<Map<String, dynamic>> _pendingCallReference(String callId) {
    return _moduleReference.collection('pendingCalls').doc(callId);
  }

  DocumentReference<Map<String, dynamic>> _confirmedCallReference(
    String callId,
  ) {
    return _moduleReference.collection('confirmedCalls').doc(callId);
  }

  DocumentReference<Map<String, dynamic>> _statisticsReference(int year) {
    return _moduleReference
        .collection('statistics')
        .doc(
          SubstitutionCallFinalizationFirestoreGateway.statisticsDocumentId(
            year,
          ),
        );
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
  Future<Map<String, dynamic>?> readStatistics({required int year}) async {
    final snapshot = await _transaction.get(_statisticsReference(year));

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  @override
  void writeStatistics({
    required int year,
    required Map<String, dynamic> data,
  }) {
    _transaction.set(_statisticsReference(year), data);
  }

  @override
  void writeConfirmedCall({
    required String callId,
    required Map<String, dynamic> data,
  }) {
    _transaction.set(_confirmedCallReference(callId), data);
  }

  @override
  void deletePendingCall({required String callId}) {
    _transaction.delete(_pendingCallReference(callId));
  }
}
