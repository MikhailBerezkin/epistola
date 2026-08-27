import 'package:epistola/domain/models/substitution_call_receipt.dart';
import 'package:epistola/services/spaces/substitution/substitution_call_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('callParticipant', () {
    test(
      'first call uses revision 1 when module has no revision yet',
      () async {
        final context = _FakeTransactionContext(
          moduleData: <String, dynamic>{'nextRotationOrder': 41},
          participants: <String, Map<String, dynamic>>{
            'user-1': <String, dynamic>{
              'rotationOrder': 15,
              'availability': 'green',
              'status': 'active',
            },
          },
        );

        final gateway = _gateway(context);

        final receipt = await gateway.callParticipant(userId: 'user-1');

        expect(receipt.userId, 'user-1');
        expect(receipt.revision, 1);

        expect(context.participantUpdates, hasLength(1));
        expect(
          context.participantUpdates.single,
          const _ParticipantUpdate(
            userId: 'user-1',
            data: <String, dynamic>{'rotationOrder': 41},
          ),
        );

        expect(context.moduleUpdates, hasLength(1));
        expect(context.moduleUpdates.single, <String, dynamic>{
          'nextRotationOrder': 42,
          'revision': 1,
          'lastCall': <String, dynamic>{
            'userId': 'user-1',
            'previousRotationOrder': 15,
            'revision': 1,
          },
        });

        expect(context.clearLastCallCount, 0);
      },
    );

    test('existing revision is incremented and stored in lastCall', () async {
      final context = _FakeTransactionContext(
        moduleData: <String, dynamic>{'nextRotationOrder': 52, 'revision': 7},
        participants: <String, Map<String, dynamic>>{
          'user-2': <String, dynamic>{
            'rotationOrder': 23,
            'availability': 'yellow',
            'status': 'active',
          },
        },
      );

      final gateway = _gateway(context);

      final receipt = await gateway.callParticipant(userId: 'user-2');

      expect(receipt.revision, 8);

      expect(context.participantUpdates.single.data, <String, dynamic>{
        'rotationOrder': 52,
      });

      expect(context.moduleUpdates.single, <String, dynamic>{
        'nextRotationOrder': 53,
        'revision': 8,
        'lastCall': <String, dynamic>{
          'userId': 'user-2',
          'previousRotationOrder': 23,
          'revision': 8,
        },
      });
    });

    test('trims userId before reading and writing participant', () async {
      final context = _FakeTransactionContext(
        moduleData: <String, dynamic>{'nextRotationOrder': 10},
        participants: <String, Map<String, dynamic>>{
          'user-3': <String, dynamic>{
            'rotationOrder': 4,
            'availability': 'green',
            'status': 'active',
          },
        },
      );

      final gateway = _gateway(context);

      final receipt = await gateway.callParticipant(userId: '  user-3  ');

      expect(receipt.userId, 'user-3');
      expect(context.participantReads, ['user-3']);
      expect(context.participantUpdates.single.userId, 'user-3');
    });

    test('rejects participant that is not active', () async {
      final context = _FakeTransactionContext(
        moduleData: <String, dynamic>{'nextRotationOrder': 11},
        participants: <String, Map<String, dynamic>>{
          'user-4': <String, dynamic>{
            'rotationOrder': 6,
            'availability': 'green',
            'status': 'vacation',
          },
        },
      );

      final gateway = _gateway(context);

      await expectLater(
        gateway.callParticipant(userId: 'user-4'),
        throwsStateError,
      );

      expect(context.participantUpdates, isEmpty);
      expect(context.moduleUpdates, isEmpty);
    });

    test('rejects missing module document', () async {
      final context = _FakeTransactionContext(
        moduleData: null,
        participants: <String, Map<String, dynamic>>{},
      );

      final gateway = _gateway(context);

      await expectLater(
        gateway.callParticipant(userId: 'user-5'),
        throwsStateError,
      );

      expect(context.participantReads, isEmpty);
      expect(context.participantUpdates, isEmpty);
      expect(context.moduleUpdates, isEmpty);
    });

    test('rejects missing participant', () async {
      final context = _FakeTransactionContext(
        moduleData: <String, dynamic>{'nextRotationOrder': 12},
        participants: <String, Map<String, dynamic>>{},
      );

      final gateway = _gateway(context);

      await expectLater(
        gateway.callParticipant(userId: 'user-6'),
        throwsStateError,
      );

      expect(context.participantUpdates, isEmpty);
      expect(context.moduleUpdates, isEmpty);
    });

    test('rejects malformed existing revision', () async {
      final context = _FakeTransactionContext(
        moduleData: <String, dynamic>{'nextRotationOrder': 12, 'revision': -1},
        participants: <String, Map<String, dynamic>>{
          'user-7': <String, dynamic>{
            'rotationOrder': 2,
            'availability': 'green',
            'status': 'active',
          },
        },
      );

      final gateway = _gateway(context);

      await expectLater(
        gateway.callParticipant(userId: 'user-7'),
        throwsStateError,
      );

      expect(context.participantUpdates, isEmpty);
      expect(context.moduleUpdates, isEmpty);
    });
  });

  group('undoLastCall', () {
    test(
      'matching latest receipt restores previous order and clears lastCall',
      () async {
        final context = _FakeTransactionContext(
          moduleData: <String, dynamic>{
            'nextRotationOrder': 42,
            'revision': 8,
            'lastCall': <String, dynamic>{
              'userId': 'user-1',
              'previousRotationOrder': 15,
              'revision': 8,
            },
          },
          participants: <String, Map<String, dynamic>>{
            'user-1': <String, dynamic>{
              'rotationOrder': 41,
              'availability': 'green',
              'status': 'active',
            },
          },
        );

        final gateway = _gateway(context);

        final undone = await gateway.undoLastCall(
          receipt: const SubstitutionCallReceipt(userId: 'user-1', revision: 8),
        );

        expect(undone, isTrue);

        expect(context.participantUpdates, hasLength(1));
        expect(
          context.participantUpdates.single,
          const _ParticipantUpdate(
            userId: 'user-1',
            data: <String, dynamic>{'rotationOrder': 15},
          ),
        );

        expect(context.moduleUpdates, isEmpty);
        expect(context.clearLastCallCount, 1);
      },
    );

    test('stale revision cannot undo a newer call', () async {
      final context = _FakeTransactionContext(
        moduleData: <String, dynamic>{
          'nextRotationOrder': 50,
          'revision': 10,
          'lastCall': <String, dynamic>{
            'userId': 'user-2',
            'previousRotationOrder': 20,
            'revision': 10,
          },
        },
        participants: <String, Map<String, dynamic>>{
          'user-2': <String, dynamic>{
            'rotationOrder': 49,
            'availability': 'green',
            'status': 'active',
          },
        },
      );

      final gateway = _gateway(context);

      final undone = await gateway.undoLastCall(
        receipt: const SubstitutionCallReceipt(userId: 'user-2', revision: 9),
      );

      expect(undone, isFalse);
      expect(context.participantReads, isEmpty);
      expect(context.participantUpdates, isEmpty);
      expect(context.moduleUpdates, isEmpty);
      expect(context.clearLastCallCount, 0);
    });

    test('receipt for another participant cannot undo last call', () async {
      final context = _FakeTransactionContext(
        moduleData: <String, dynamic>{
          'nextRotationOrder': 50,
          'revision': 10,
          'lastCall': <String, dynamic>{
            'userId': 'user-2',
            'previousRotationOrder': 20,
            'revision': 10,
          },
        },
        participants: <String, Map<String, dynamic>>{
          'user-2': <String, dynamic>{
            'rotationOrder': 49,
            'availability': 'green',
            'status': 'active',
          },
        },
      );

      final gateway = _gateway(context);

      final undone = await gateway.undoLastCall(
        receipt: const SubstitutionCallReceipt(userId: 'user-3', revision: 10),
      );

      expect(undone, isFalse);
      expect(context.participantReads, isEmpty);
      expect(context.participantUpdates, isEmpty);
      expect(context.clearLastCallCount, 0);
    });

    test('missing lastCall returns false', () async {
      final context = _FakeTransactionContext(
        moduleData: <String, dynamic>{'nextRotationOrder': 42, 'revision': 8},
        participants: <String, Map<String, dynamic>>{},
      );

      final gateway = _gateway(context);

      final undone = await gateway.undoLastCall(
        receipt: const SubstitutionCallReceipt(userId: 'user-1', revision: 8),
      );

      expect(undone, isFalse);
      expect(context.participantReads, isEmpty);
      expect(context.clearLastCallCount, 0);
    });

    test('missing called participant returns false', () async {
      final context = _FakeTransactionContext(
        moduleData: <String, dynamic>{
          'nextRotationOrder': 42,
          'revision': 8,
          'lastCall': <String, dynamic>{
            'userId': 'user-1',
            'previousRotationOrder': 15,
            'revision': 8,
          },
        },
        participants: <String, Map<String, dynamic>>{},
      );

      final gateway = _gateway(context);

      final undone = await gateway.undoLastCall(
        receipt: const SubstitutionCallReceipt(userId: 'user-1', revision: 8),
      );

      expect(undone, isFalse);
      expect(context.participantUpdates, isEmpty);
      expect(context.clearLastCallCount, 0);
    });

    test('invalid receipt revision is rejected before transaction', () {
      final context = _FakeTransactionContext(
        moduleData: <String, dynamic>{'nextRotationOrder': 42},
        participants: <String, Map<String, dynamic>>{},
      );

      final runner = _FakeTransactionRunner(context);
      final gateway = SubstitutionCallFirestoreGateway(runner);

      expect(
        () => gateway.undoLastCall(
          receipt: const SubstitutionCallReceipt(userId: 'user-1', revision: 0),
        ),
        throwsArgumentError,
      );

      expect(runner.runCount, 0);
    });
  });
}

SubstitutionCallFirestoreGateway _gateway(_FakeTransactionContext context) {
  return SubstitutionCallFirestoreGateway(_FakeTransactionRunner(context));
}

final class _FakeTransactionRunner
    implements SubstitutionCallTransactionRunner {
  _FakeTransactionRunner(this.context);

  final SubstitutionCallTransactionContext context;

  int runCount = 0;

  @override
  Future<T> run<T>(
    Future<T> Function(SubstitutionCallTransactionContext context) action,
  ) async {
    runCount += 1;
    return action(context);
  }
}

final class _FakeTransactionContext
    implements SubstitutionCallTransactionContext {
  _FakeTransactionContext({
    required Map<String, dynamic>? moduleData,
    required Map<String, Map<String, dynamic>> participants,
  }) : _moduleData = moduleData == null
           ? null
           : Map<String, dynamic>.from(moduleData),
       _participants = participants.map(
         (userId, data) => MapEntry(userId, Map<String, dynamic>.from(data)),
       );

  final Map<String, dynamic>? _moduleData;
  final Map<String, Map<String, dynamic>> _participants;

  final List<String> participantReads = <String>[];
  final List<Map<String, dynamic>> moduleUpdates = <Map<String, dynamic>>[];
  final List<_ParticipantUpdate> participantUpdates = <_ParticipantUpdate>[];

  int clearLastCallCount = 0;

  @override
  Future<Map<String, dynamic>?> readModule() async {
    final data = _moduleData;

    if (data == null) {
      return null;
    }

    return Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>?> readParticipant({
    required String userId,
  }) async {
    participantReads.add(userId);

    final data = _participants[userId];

    if (data == null) {
      return null;
    }

    return Map<String, dynamic>.from(data);
  }

  @override
  void updateModule(Map<String, dynamic> data) {
    moduleUpdates.add(Map<String, dynamic>.from(data));
  }

  @override
  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    participantUpdates.add(
      _ParticipantUpdate(userId: userId, data: Map<String, dynamic>.from(data)),
    );
  }

  @override
  void clearLastCall() {
    clearLastCallCount += 1;
  }
}

final class _ParticipantUpdate {
  const _ParticipantUpdate({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;

  @override
  bool operator ==(Object other) {
    return other is _ParticipantUpdate &&
        other.userId == userId &&
        _mapEquals(other.data, data);
  }

  @override
  int get hashCode => Object.hash(
    userId,
    Object.hashAll(
      data.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

bool _mapEquals(Map<String, dynamic> left, Map<String, dynamic> right) {
  if (left.length != right.length) {
    return false;
  }

  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }

  return true;
}
