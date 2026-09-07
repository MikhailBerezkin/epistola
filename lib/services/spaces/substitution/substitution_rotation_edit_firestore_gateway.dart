import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_participant.dart';
import 'substitution_participant_mapper.dart';

typedef SubstitutionRotationEditStoredBaseline = ({
  int nextRotationOrder,
  int revision,
});

typedef SubstitutionRotationEditModuleLoader =
    Future<Map<String, dynamic>?> Function();

typedef SubstitutionRotationEditPendingCallLoader =
    Future<Map<String, dynamic>?> Function({required String callId});

abstract interface class SubstitutionRotationEditTransactionContext {
  Future<Map<String, dynamic>?> readModule();

  Future<Map<String, dynamic>?> readParticipant({required String userId});

  Future<Map<String, dynamic>?> readPendingCall({required String callId});

  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  });

  void updateModule(Map<String, dynamic> data);
}

abstract interface class SubstitutionRotationEditTransactionRunner {
  Future<T> run<T>(
    Future<T> Function(SubstitutionRotationEditTransactionContext context)
    action,
  );
}

final class SubstitutionRotationEditFirestoreGateway {
  SubstitutionRotationEditFirestoreGateway({
    required SubstitutionRotationEditModuleLoader moduleLoader,
    required SubstitutionRotationEditPendingCallLoader pendingCallLoader,
    required this.transactionRunner,
  }) : _loadModule = moduleLoader,
       _loadPendingCall = pendingCallLoader;

  factory SubstitutionRotationEditFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final moduleReference = resolvedFirestore
        .collection('spaces')
        .doc('substitution');

    final pendingCallsReference = moduleReference.collection('pendingCalls');

    return SubstitutionRotationEditFirestoreGateway(
      moduleLoader: () async {
        final snapshot = await moduleReference.get();

        if (!snapshot.exists) {
          return null;
        }

        return snapshot.data();
      },
      pendingCallLoader: ({required String callId}) async {
        final snapshot = await pendingCallsReference.doc(callId).get();

        if (!snapshot.exists) {
          return null;
        }

        return snapshot.data();
      },
      transactionRunner: _FirebaseSubstitutionRotationEditTransactionRunner(
        resolvedFirestore,
      ),
    );
  }

  final SubstitutionRotationEditModuleLoader _loadModule;
  final SubstitutionRotationEditPendingCallLoader _loadPendingCall;
  final SubstitutionRotationEditTransactionRunner transactionRunner;

  static const String nextRotationOrderField = 'nextRotationOrder';

  static const String revisionField = 'revision';

  static const String lastCallField = 'lastCall';
  static const String lastCallRevisionField = 'revision';

  Future<SubstitutionRotationEditStoredBaseline> loadBaseline() async {
    final moduleData = await _loadModule();

    if (moduleData == null) {
      throw StateError('Substitution module document does not exist.');
    }

    final baseline = _baselineFromModule(moduleData);

    final pendingCallId = _pendingCallIdFromModule(moduleData);

    if (pendingCallId != null) {
      final pendingCall = await _loadPendingCall(callId: pendingCallId);

      if (pendingCall != null) {
        throw StateError(
          'Substitution rotation cannot be edited '
          'while a call is pending.',
        );
      }
    }

    return baseline;
  }

  Future<bool> applyOrder({
    required List<SubstitutionParticipant> originalParticipants,
    required List<SubstitutionParticipant> participants,
    required int expectedNextRotationOrder,
    required int expectedRevision,
  }) {
    if (expectedNextRotationOrder < 0) {
      throw ArgumentError.value(
        expectedNextRotationOrder,
        'expectedNextRotationOrder',
        'expectedNextRotationOrder must be non-negative.',
      );
    }

    if (expectedRevision < 0) {
      throw ArgumentError.value(
        expectedRevision,
        'expectedRevision',
        'expectedRevision must be non-negative.',
      );
    }

    _validateParticipantLists(
      originalParticipants: originalParticipants,
      participants: participants,
    );

    final originalByUserId = <String, SubstitutionParticipant>{
      for (final participant in originalParticipants)
        participant.userId: participant,
    };

    final targetByUserId = <String, SubstitutionParticipant>{
      for (final participant in participants) participant.userId: participant,
    };

    return transactionRunner.run((context) async {
      final moduleData = await context.readModule();

      if (moduleData == null) {
        return false;
      }

      final currentBaseline = _baselineFromModule(moduleData);

      if (currentBaseline.nextRotationOrder != expectedNextRotationOrder ||
          currentBaseline.revision != expectedRevision) {
        return false;
      }

      final pendingCallId = _pendingCallIdFromModule(moduleData);

      if (pendingCallId != null) {
        final pendingCall = await context.readPendingCall(
          callId: pendingCallId,
        );

        if (pendingCall != null) {
          return false;
        }
      }

      final currentParticipants = <String, SubstitutionParticipant>{};

      // Firestore transaction:
      // сначала выполняем абсолютно все чтения.
      for (final original in originalParticipants) {
        final participantData = await context.readParticipant(
          userId: original.userId,
        );

        if (participantData == null) {
          return false;
        }

        final currentParticipant = SubstitutionParticipantMapper.fromMap(
          userId: original.userId,
          data: participantData,
        );

        if (currentParticipant == null) {
          throw StateError(
            'Substitution participant document '
            'contains invalid data.',
          );
        }

        currentParticipants[original.userId] = currentParticipant;
      }

      // Проверяем, что за время редактирования
      // фактический порядок не изменился.
      for (final entry in currentParticipants.entries) {
        final original = originalByUserId[entry.key]!;

        if (entry.value.rotationOrder != original.rotationOrder) {
          return false;
        }
      }

      // После всех проверок выполняем только записи порядка.
      for (final entry in currentParticipants.entries) {
        final currentParticipant = entry.value;
        final targetParticipant = targetByUserId[entry.key]!;

        if (currentParticipant.rotationOrder ==
            targetParticipant.rotationOrder) {
          continue;
        }

        context.updateParticipant(
          userId: entry.key,
          data: <String, dynamic>{
            SubstitutionParticipantMapper.rotationOrderField:
                targetParticipant.rotationOrder,
          },
        );
      }

      final targetNextRotationOrder = currentBaseline.nextRotationOrder + 1;

      context.updateModule(<String, dynamic>{
        nextRotationOrderField: targetNextRotationOrder,
      });

      return true;
    });
  }

  static SubstitutionRotationEditStoredBaseline _baselineFromModule(
    Map<String, dynamic> moduleData,
  ) {
    final nextRotationOrder = _readNonNegativeInt(
      moduleData,
      nextRotationOrderField,
      documentName: 'substitution module',
    );

    final revisionValue = moduleData[revisionField];

    final revision = revisionValue == null
        ? 0
        : _readNonNegativeInt(
            moduleData,
            revisionField,
            documentName: 'substitution module',
          );

    return (nextRotationOrder: nextRotationOrder, revision: revision);
  }

  static String? _pendingCallIdFromModule(Map<String, dynamic> moduleData) {
    final lastCallRaw = moduleData[lastCallField];

    if (lastCallRaw == null) {
      return null;
    }

    if (lastCallRaw is! Map) {
      throw StateError('Substitution module lastCall must be a map.');
    }

    final lastCall = Map<String, dynamic>.from(lastCallRaw);

    final revision = lastCall[lastCallRevisionField];

    if (revision is! int || revision < 1) {
      throw StateError(
        'Substitution module lastCall revision '
        'must be a positive integer.',
      );
    }

    return revision.toString();
  }

  static void _validateParticipantLists({
    required List<SubstitutionParticipant> originalParticipants,
    required List<SubstitutionParticipant> participants,
  }) {
    if (originalParticipants.isEmpty || participants.isEmpty) {
      throw ArgumentError('Substitution rotation must contain participants.');
    }

    if (originalParticipants.length != participants.length) {
      throw ArgumentError(
        'Original and target rotations '
        'must contain the same participants.',
      );
    }

    final originalUserIds = <String>{};

    for (final participant in originalParticipants) {
      _validateUserId(participant.userId);

      if (!originalUserIds.add(participant.userId)) {
        throw ArgumentError('Original rotation contains duplicate user ids.');
      }
    }

    final targetUserIds = <String>{};

    for (var index = 0; index < participants.length; index++) {
      final participant = participants[index];

      _validateUserId(participant.userId);

      if (!targetUserIds.add(participant.userId)) {
        throw ArgumentError('Target rotation contains duplicate user ids.');
      }

      if (participant.rotationOrder != index) {
        throw ArgumentError('Target rotation must be normalized.');
      }
    }

    if (originalUserIds.length != targetUserIds.length ||
        !originalUserIds.containsAll(targetUserIds)) {
      throw ArgumentError(
        'Original and target rotations '
        'must contain the same user ids.',
      );
    }
  }

  static int _readNonNegativeInt(
    Map<String, dynamic> data,
    String field, {
    required String documentName,
  }) {
    final value = data[field];

    if (value is! int || value < 0) {
      throw StateError(
        '$documentName field "$field" '
        'must be a non-negative integer.',
      );
    }

    return value;
  }

  static void _validateUserId(String value) {
    if (value.isEmpty || value != value.trim() || value.contains('/')) {
      throw ArgumentError.value(
        value,
        'userId',
        'userId must be non-empty, trimmed '
            'and must not contain slashes.',
      );
    }
  }
}

final class _FirebaseSubstitutionRotationEditTransactionRunner
    implements SubstitutionRotationEditTransactionRunner {
  _FirebaseSubstitutionRotationEditTransactionRunner(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<T> run<T>(
    Future<T> Function(SubstitutionRotationEditTransactionContext context)
    action,
  ) {
    final moduleReference = _firestore.collection('spaces').doc('substitution');

    return _firestore.runTransaction((transaction) {
      final context = _FirebaseSubstitutionRotationEditTransactionContext(
        transaction,
        moduleReference,
      );

      return action(context);
    });
  }
}

final class _FirebaseSubstitutionRotationEditTransactionContext
    implements SubstitutionRotationEditTransactionContext {
  _FirebaseSubstitutionRotationEditTransactionContext(
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
  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    _transaction.update(_participantReference(userId), data);
  }

  @override
  void updateModule(Map<String, dynamic> data) {
    _transaction.update(_moduleReference, data);
  }
}
