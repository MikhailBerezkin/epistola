import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_participant.dart';
import '../../../domain/models/substitution_rotation.dart';
import 'substitution_participant_mapper.dart';

final class SubstitutionParticipantsBaseline {
  const SubstitutionParticipantsBaseline({
    required this.moduleExists,
    required this.nextRotationOrder,
    required this.revision,
    required this.participants,
    required this.hasPendingCall,
  });

  final bool moduleExists;
  final int nextRotationOrder;
  final int revision;
  final List<SubstitutionParticipant> participants;
  final bool hasPendingCall;
}

typedef SubstitutionParticipantsBaselineLoader =
    Future<SubstitutionParticipantsBaseline> Function();

abstract interface class SubstitutionParticipantsTransactionContext {
  Future<Map<String, dynamic>?> readModule();

  Future<Map<String, dynamic>?> readParticipant({required String userId});

  void createParticipant({
    required String userId,
    required Map<String, dynamic> data,
  });

  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  });

  void setModule(Map<String, dynamic> data);
}

abstract interface class SubstitutionParticipantsTransactionRunner {
  Future<T> run<T>(
    Future<T> Function(SubstitutionParticipantsTransactionContext context)
    action,
  );
}

final class SubstitutionRotationMembershipFirestoreGateway {
  factory SubstitutionRotationMembershipFirestoreGateway({
    required SubstitutionParticipantsBaselineLoader baselineLoader,
    required SubstitutionParticipantsTransactionRunner transactionRunner,
  }) {
    return SubstitutionRotationMembershipFirestoreGateway._(
      baselineLoader,
      transactionRunner,
    );
  }

  SubstitutionRotationMembershipFirestoreGateway._(
    this._loadBaseline,
    this._transactionRunner,
  );

  factory SubstitutionRotationMembershipFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final moduleReference = resolvedFirestore
        .collection('spaces')
        .doc('substitution');

    final participantsReference = moduleReference.collection('participants');

    return SubstitutionRotationMembershipFirestoreGateway(
      baselineLoader: () async {
        final moduleSnapshot = await moduleReference.get();

        final participantsSnapshot = await participantsReference.get();

        final participants = <SubstitutionParticipant>[];

        for (final document in participantsSnapshot.docs) {
          final participant = SubstitutionParticipantMapper.fromMap(
            userId: document.id,
            data: document.data(),
          );

          if (participant == null) {
            throw StateError(
              'Substitution participant '
              '${document.id} contains invalid data.',
            );
          }

          participants.add(participant);
        }

        final orderedParticipants = SubstitutionRotation.ordered(participants);

        if (!moduleSnapshot.exists) {
          if (orderedParticipants.isNotEmpty) {
            throw StateError(
              'Substitution module is missing '
              'while participants exist.',
            );
          }

          return const SubstitutionParticipantsBaseline(
            moduleExists: false,
            nextRotationOrder: 0,
            revision: 0,
            participants: <SubstitutionParticipant>[],
            hasPendingCall: false,
          );
        }

        final moduleData = moduleSnapshot.data();

        if (moduleData == null) {
          throw StateError('Substitution module contains no data.');
        }

        final nextRotationOrder = _readNonNegativeInt(
          moduleData,
          'nextRotationOrder',
          documentName: 'substitution module',
        );

        final revision = _readRevision(moduleData);

        final minimumNextRotationOrder = SubstitutionRotation.nextRotationOrder(
          orderedParticipants,
        );

        if (nextRotationOrder < minimumNextRotationOrder) {
          throw StateError(
            'Substitution nextRotationOrder '
            'is behind participant rotation.',
          );
        }

        var hasPendingCall = false;

        final lastCallRaw = moduleData['lastCall'];

        if (lastCallRaw != null) {
          if (lastCallRaw is! Map) {
            throw StateError(
              'Substitution lastCall '
              'contains invalid data.',
            );
          }

          final lastCallRevision = lastCallRaw['revision'];

          if (lastCallRevision is! int || lastCallRevision < 1) {
            throw StateError(
              'Substitution lastCall revision '
              'contains invalid data.',
            );
          }

          final pendingSnapshot = await moduleReference
              .collection('pendingCalls')
              .doc(lastCallRevision.toString())
              .get();

          hasPendingCall = pendingSnapshot.exists;
        }

        return SubstitutionParticipantsBaseline(
          moduleExists: true,
          nextRotationOrder: nextRotationOrder,
          revision: revision,
          participants: orderedParticipants,
          hasPendingCall: hasPendingCall,
        );
      },
      transactionRunner: _FirebaseSubstitutionParticipantsTransactionRunner(
        resolvedFirestore,
      ),
    );
  }

  static const int _maxApplyAttempts = 3;

  final SubstitutionParticipantsBaselineLoader _loadBaseline;

  final SubstitutionParticipantsTransactionRunner _transactionRunner;

  Future<int> addParticipants(List<String> userIds) async {
    for (var attempt = 0; attempt < _maxApplyAttempts; attempt++) {
      final baseline = await _loadBaseline();

      _validateBaseline(baseline);

      if (baseline.hasPendingCall) {
        throw StateError(
          'Substitution participants cannot be '
          'changed while a call is pending.',
        );
      }

      final addition = SubstitutionRotation.addOrRestoreParticipants(
        participants: baseline.participants,
        userIds: userIds,
      );

      if (addition.addedCount == 0) {
        return 0;
      }

      final applied = await _transactionRunner.run((context) {
        return _applyAddition(
          context: context,
          baseline: baseline,
          addition: addition,
        );
      });

      if (applied) {
        return addition.addedCount;
      }
    }

    throw StateError(
      'Substitution rotation changed '
      'while participants were being added.',
    );
  }

  Future<void> removeParticipant({required String userId}) async {
    final normalizedUserId = _normalizeUserId(userId);

    for (var attempt = 0; attempt < _maxApplyAttempts; attempt++) {
      final baseline = await _loadBaseline();

      _validateBaseline(baseline);

      if (baseline.hasPendingCall) {
        throw StateError(
          'Substitution participants cannot be '
          'changed while a call is pending.',
        );
      }

      SubstitutionParticipant? originalParticipant;

      for (final participant in baseline.participants) {
        if (participant.userId == normalizedUserId) {
          originalParticipant = participant;
          break;
        }
      }

      if (originalParticipant == null) {
        throw StateError('Participant is not in the substitution rotation.');
      }

      if (originalParticipant.isRemoved) {
        return;
      }

      final applied = await _transactionRunner.run((context) {
        return _applyRemoval(
          context: context,
          baseline: baseline,
          originalParticipant: originalParticipant!,
        );
      });

      if (applied) {
        return;
      }
    }

    throw StateError(
      'Substitution rotation changed '
      'while participant was being removed.',
    );
  }

  Future<bool> _applyAddition({
    required SubstitutionParticipantsTransactionContext context,
    required SubstitutionParticipantsBaseline baseline,
    required SubstitutionRotationAddition addition,
  }) async {
    final moduleData = await context.readModule();

    if (baseline.moduleExists) {
      if (moduleData == null) {
        return false;
      }

      final currentNextRotationOrder = _readNonNegativeInt(
        moduleData,
        'nextRotationOrder',
        documentName: 'substitution module',
      );

      final currentRevision = _readRevision(moduleData);

      if (currentNextRotationOrder != baseline.nextRotationOrder ||
          currentRevision != baseline.revision) {
        return false;
      }
    } else if (moduleData != null) {
      return false;
    }

    final currentParticipants = <String, SubstitutionParticipant>{};

    // Все чтения выполняются до первой записи.
    for (final original in baseline.participants) {
      final data = await context.readParticipant(userId: original.userId);

      if (data == null) {
        return false;
      }

      final current = SubstitutionParticipantMapper.fromMap(
        userId: original.userId,
        data: data,
      );

      if (current == null) {
        throw StateError(
          'Substitution participant '
          '${original.userId} contains invalid data.',
        );
      }

      if (current.rotationOrder != original.rotationOrder ||
          current.status != original.status) {
        return false;
      }

      currentParticipants[original.userId] = current;
    }

    for (final userId in addition.createdUserIds) {
      final existing = await context.readParticipant(userId: userId);

      if (existing != null) {
        return false;
      }
    }

    final targetById = <String, SubstitutionParticipant>{
      for (final participant in addition.participants)
        participant.userId: participant,
    };

    for (final original in baseline.participants) {
      final current = currentParticipants[original.userId]!;

      final target = targetById[original.userId];

      if (target == null) {
        throw StateError(
          'Participant ${original.userId} '
          'is missing from addition result.',
        );
      }

      final update = <String, dynamic>{};

      if (target.rotationOrder != current.rotationOrder) {
        update[SubstitutionParticipantMapper.rotationOrderField] =
            target.rotationOrder;
      }

      if (target.status != current.status) {
        update[SubstitutionParticipantMapper.statusField] =
            target.status.storageValue;
      }

      if (update.isNotEmpty) {
        context.updateParticipant(userId: original.userId, data: update);
      }
    }

    for (final userId in addition.createdUserIds) {
      final target = targetById[userId];

      if (target == null) {
        throw StateError(
          'New participant $userId '
          'is missing from addition result.',
        );
      }

      context.createParticipant(
        userId: userId,
        data: SubstitutionParticipantMapper.toMap(target),
      );
    }

    final createdCount = addition.createdUserIds.length;

    final restoredCount = addition.restoredUserIds.length;

    final nextOrderAdvance = createdCount > 0
        ? createdCount
        : restoredCount > 0
        ? 1
        : 0;

    if (nextOrderAdvance > 0) {
      context.setModule(<String, dynamic>{
        'nextRotationOrder': baseline.nextRotationOrder + nextOrderAdvance,
      });
    }

    return true;
  }

  Future<bool> _applyRemoval({
    required SubstitutionParticipantsTransactionContext context,
    required SubstitutionParticipantsBaseline baseline,
    required SubstitutionParticipant originalParticipant,
  }) async {
    final moduleData = await context.readModule();

    if (!baseline.moduleExists || moduleData == null) {
      return false;
    }

    final currentNextRotationOrder = _readNonNegativeInt(
      moduleData,
      'nextRotationOrder',
      documentName: 'substitution module',
    );

    final currentRevision = _readRevision(moduleData);

    if (currentNextRotationOrder != baseline.nextRotationOrder ||
        currentRevision != baseline.revision) {
      return false;
    }

    final participantData = await context.readParticipant(
      userId: originalParticipant.userId,
    );

    if (participantData == null) {
      return false;
    }

    final currentParticipant = SubstitutionParticipantMapper.fromMap(
      userId: originalParticipant.userId,
      data: participantData,
    );

    if (currentParticipant == null) {
      throw StateError(
        'Substitution participant '
        '${originalParticipant.userId} contains invalid data.',
      );
    }

    if (currentParticipant.rotationOrder != originalParticipant.rotationOrder ||
        currentParticipant.status != originalParticipant.status) {
      return false;
    }

    context.updateParticipant(
      userId: originalParticipant.userId,
      data: const <String, dynamic>{
        SubstitutionParticipantMapper.statusField: 'removed',
      },
    );

    context.setModule(<String, dynamic>{
      'nextRotationOrder': baseline.nextRotationOrder + 1,
    });

    return true;
  }

  static void _validateBaseline(SubstitutionParticipantsBaseline baseline) {
    if (baseline.nextRotationOrder < 0) {
      throw StateError(
        'Substitution nextRotationOrder '
        'must be non-negative.',
      );
    }

    if (baseline.revision < 0) {
      throw StateError(
        'Substitution revision '
        'must be non-negative.',
      );
    }

    if (!baseline.moduleExists && baseline.participants.isNotEmpty) {
      throw StateError(
        'Substitution module is missing '
        'while participants exist.',
      );
    }

    final seenUserIds = <String>{};
    final seenRotationOrders = <int>{};

    for (final participant in baseline.participants) {
      if (!seenUserIds.add(participant.userId)) {
        throw StateError(
          'Duplicate substitution participant '
          '${participant.userId}.',
        );
      }

      if (!seenRotationOrders.add(participant.rotationOrder)) {
        throw StateError(
          'Duplicate substitution rotationOrder '
          '${participant.rotationOrder}.',
        );
      }
    }

    if (baseline.moduleExists) {
      final minimumNextRotationOrder = SubstitutionRotation.nextRotationOrder(
        baseline.participants,
      );

      if (baseline.nextRotationOrder < minimumNextRotationOrder) {
        throw StateError(
          'Substitution nextRotationOrder '
          'is behind participant rotation.',
        );
      }
    }
  }

  static int _readRevision(Map<String, dynamic> data) {
    final value = data['revision'];

    if (value == null) {
      return 0;
    }

    if (value is! int || value < 0) {
      throw StateError(
        'Substitution module revision '
        'must be a non-negative integer.',
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
        'userId must be non-empty '
            'and must not contain slashes.',
      );
    }

    return normalized;
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
}

final class _FirebaseSubstitutionParticipantsTransactionRunner
    implements SubstitutionParticipantsTransactionRunner {
  _FirebaseSubstitutionParticipantsTransactionRunner(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<T> run<T>(
    Future<T> Function(SubstitutionParticipantsTransactionContext context)
    action,
  ) {
    final moduleReference = _firestore.collection('spaces').doc('substitution');

    return _firestore.runTransaction<T>((transaction) {
      final context = _FirebaseSubstitutionParticipantsTransactionContext(
        transaction,
        moduleReference,
      );

      return action(context);
    });
  }
}

final class _FirebaseSubstitutionParticipantsTransactionContext
    implements SubstitutionParticipantsTransactionContext {
  _FirebaseSubstitutionParticipantsTransactionContext(
    this._transaction,
    this._moduleReference,
  );

  final Transaction _transaction;

  final DocumentReference<Map<String, dynamic>> _moduleReference;

  DocumentReference<Map<String, dynamic>> _participantReference(String userId) {
    return _moduleReference.collection('participants').doc(userId);
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
  void createParticipant({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    _transaction.set(_participantReference(userId), data);
  }

  @override
  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    _transaction.update(_participantReference(userId), data);
  }

  @override
  void setModule(Map<String, dynamic> data) {
    _transaction.set(_moduleReference, data, SetOptions(merge: true));
  }
}
