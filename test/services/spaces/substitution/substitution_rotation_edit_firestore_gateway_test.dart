import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/services/spaces/substitution/substitution_rotation_edit_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SubstitutionParticipant participant(String userId, int rotationOrder) {
    return SubstitutionParticipant(
      userId: userId,
      rotationOrder: rotationOrder,
    );
  }

  Map<String, dynamic> participantData(int rotationOrder) {
    return <String, dynamic>{
      'rotationOrder': rotationOrder,
      'availability': 'green',
      'status': 'active',
    };
  }

  test('loads baseline from module', () async {
    final gateway = _gateway(
      module: <String, dynamic>{'nextRotationOrder': 40, 'revision': 12},
    );

    final baseline = await gateway.loadBaseline();

    expect(baseline.nextRotationOrder, 40);
    expect(baseline.revision, 12);
  });

  test('missing module revision is treated as zero', () async {
    final gateway = _gateway(
      module: <String, dynamic>{'nextRotationOrder': 40},
    );

    final baseline = await gateway.loadBaseline();

    expect(baseline.nextRotationOrder, 40);
    expect(baseline.revision, 0);
  });

  test('baseline rejects active pending call', () async {
    final gateway = _gateway(
      module: <String, dynamic>{
        'nextRotationOrder': 40,
        'revision': 12,
        'lastCall': <String, dynamic>{'revision': 12},
      },
      pendingCalls: <String, Map<String, dynamic>>{
        '12': <String, dynamic>{'callId': '12'},
      },
    );

    expect(gateway.loadBaseline, throwsStateError);
  });

  test('applies normalized order atomically', () async {
    final context = _FakeTransactionContext(
      module: <String, dynamic>{'nextRotationOrder': 90, 'revision': 7},
      participants: <String, Map<String, dynamic>>{
        'user-a': participantData(10),
        'user-b': participantData(30),
        'user-c': participantData(80),
      },
    );

    final gateway = _gateway(module: context.module, context: context);

    final applied = await gateway.applyOrder(
      originalParticipants: [
        participant('user-a', 10),
        participant('user-b', 30),
        participant('user-c', 80),
      ],
      participants: [
        participant('user-a', 0),
        participant('user-c', 1),
        participant('user-b', 2),
      ],
      expectedNextRotationOrder: 90,
      expectedRevision: 7,
    );

    expect(applied, isTrue);

    expect(context.participantUpdates, [
      const _ParticipantUpdate(userId: 'user-a', rotationOrder: 0),
      const _ParticipantUpdate(userId: 'user-b', rotationOrder: 2),
      const _ParticipantUpdate(userId: 'user-c', rotationOrder: 1),
    ]);

    expect(context.moduleUpdates, [
      const {'nextRotationOrder': 91},
    ]);
  });

  test('writes only rotationOrder to participants', () async {
    final context = _FakeTransactionContext(
      module: <String, dynamic>{'nextRotationOrder': 20, 'revision': 4},
      participants: <String, Map<String, dynamic>>{
        'user-a': <String, dynamic>{
          'rotationOrder': 10,
          'availability': 'yellow',
          'status': 'active',
        },
        'user-b': <String, dynamic>{
          'rotationOrder': 19,
          'availability': 'green',
          'status': 'vacation',
        },
      },
    );

    final gateway = _gateway(module: context.module, context: context);

    final applied = await gateway.applyOrder(
      originalParticipants: [
        SubstitutionParticipant(
          userId: 'user-a',
          rotationOrder: 10,
          availability: SubstitutionAvailability.yellow,
        ),
        SubstitutionParticipant(
          userId: 'user-b',
          rotationOrder: 19,
          status: SubstitutionParticipantStatus.vacation,
        ),
      ],
      participants: [
        SubstitutionParticipant(
          userId: 'user-b',
          rotationOrder: 0,
          status: SubstitutionParticipantStatus.vacation,
        ),
        SubstitutionParticipant(
          userId: 'user-a',
          rotationOrder: 1,
          availability: SubstitutionAvailability.yellow,
        ),
      ],
      expectedNextRotationOrder: 20,
      expectedRevision: 4,
    );

    expect(applied, isTrue);

    for (final data in context.rawParticipantUpdates) {
      expect(data.keys, {'rotationOrder'});
    }
  });

  test('module baseline change produces conflict', () async {
    final context = _FakeTransactionContext(
      module: <String, dynamic>{'nextRotationOrder': 31, 'revision': 9},
      participants: <String, Map<String, dynamic>>{
        'user-a': participantData(10),
        'user-b': participantData(20),
      },
    );

    final gateway = _gateway(module: context.module, context: context);

    final applied = await gateway.applyOrder(
      originalParticipants: [
        participant('user-a', 10),
        participant('user-b', 20),
      ],
      participants: [participant('user-b', 0), participant('user-a', 1)],
      expectedNextRotationOrder: 30,
      expectedRevision: 9,
    );

    expect(applied, isFalse);
    expect(context.participantUpdates, isEmpty);
    expect(context.moduleUpdates, isEmpty);
  });

  test('participant order change produces conflict', () async {
    final context = _FakeTransactionContext(
      module: <String, dynamic>{'nextRotationOrder': 30, 'revision': 9},
      participants: <String, Map<String, dynamic>>{
        'user-a': participantData(11),
        'user-b': participantData(20),
      },
    );

    final gateway = _gateway(module: context.module, context: context);

    final applied = await gateway.applyOrder(
      originalParticipants: [
        participant('user-a', 10),
        participant('user-b', 20),
      ],
      participants: [participant('user-b', 0), participant('user-a', 1)],
      expectedNextRotationOrder: 30,
      expectedRevision: 9,
    );

    expect(applied, isFalse);
    expect(context.participantUpdates, isEmpty);
  });

  test('pending call appearing before apply produces conflict', () async {
    final context = _FakeTransactionContext(
      module: <String, dynamic>{
        'nextRotationOrder': 30,
        'revision': 9,
        'lastCall': <String, dynamic>{'revision': 9},
      },
      participants: <String, Map<String, dynamic>>{
        'user-a': participantData(10),
        'user-b': participantData(20),
      },
      pendingCalls: <String, Map<String, dynamic>>{
        '9': <String, dynamic>{'callId': '9'},
      },
    );

    final gateway = _gateway(module: context.module, context: context);

    final applied = await gateway.applyOrder(
      originalParticipants: [
        participant('user-a', 10),
        participant('user-b', 20),
      ],
      participants: [participant('user-b', 0), participant('user-a', 1)],
      expectedNextRotationOrder: 30,
      expectedRevision: 9,
    );

    expect(applied, isFalse);
    expect(context.participantUpdates, isEmpty);
  });

  test('rejects non-normalized target order', () {
    final gateway = _gateway(
      module: <String, dynamic>{'nextRotationOrder': 30, 'revision': 9},
    );

    expect(
      () => gateway.applyOrder(
        originalParticipants: [
          participant('user-a', 10),
          participant('user-b', 20),
        ],
        participants: [participant('user-b', 5), participant('user-a', 6)],
        expectedNextRotationOrder: 30,
        expectedRevision: 9,
      ),
      throwsArgumentError,
    );
  });
}

SubstitutionRotationEditFirestoreGateway _gateway({
  required Map<String, dynamic> module,
  Map<String, Map<String, dynamic>> pendingCalls =
      const <String, Map<String, dynamic>>{},
  _FakeTransactionContext? context,
}) {
  final resolvedContext =
      context ??
      _FakeTransactionContext(
        module: module,
        participants: const <String, Map<String, dynamic>>{},
        pendingCalls: pendingCalls,
      );

  return SubstitutionRotationEditFirestoreGateway(
    moduleLoader: () async {
      return Map<String, dynamic>.from(module);
    },
    pendingCallLoader: ({required String callId}) async {
      final data = pendingCalls[callId];

      return data == null ? null : Map<String, dynamic>.from(data);
    },
    transactionRunner: _FakeTransactionRunner(resolvedContext),
  );
}

final class _FakeTransactionRunner
    implements SubstitutionRotationEditTransactionRunner {
  const _FakeTransactionRunner(this.context);

  final _FakeTransactionContext context;

  @override
  Future<T> run<T>(
    Future<T> Function(SubstitutionRotationEditTransactionContext context)
    action,
  ) {
    return action(context);
  }
}

final class _FakeTransactionContext
    implements SubstitutionRotationEditTransactionContext {
  _FakeTransactionContext({
    required Map<String, dynamic> module,
    required Map<String, Map<String, dynamic>> participants,
    Map<String, Map<String, dynamic>> pendingCalls =
        const <String, Map<String, dynamic>>{},
  }) : module = Map<String, dynamic>.from(module),
       participants = {
         for (final entry in participants.entries)
           entry.key: Map<String, dynamic>.from(entry.value),
       },
       pendingCalls = {
         for (final entry in pendingCalls.entries)
           entry.key: Map<String, dynamic>.from(entry.value),
       };

  final Map<String, dynamic> module;

  final Map<String, Map<String, dynamic>> participants;

  final Map<String, Map<String, dynamic>> pendingCalls;

  final List<_ParticipantUpdate> participantUpdates = [];

  final List<Map<String, dynamic>> rawParticipantUpdates = [];

  final List<Map<String, dynamic>> moduleUpdates = [];

  @override
  Future<Map<String, dynamic>?> readModule() async {
    return Map<String, dynamic>.from(module);
  }

  @override
  Future<Map<String, dynamic>?> readParticipant({
    required String userId,
  }) async {
    final data = participants[userId];

    return data == null ? null : Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>?> readPendingCall({
    required String callId,
  }) async {
    final data = pendingCalls[callId];

    return data == null ? null : Map<String, dynamic>.from(data);
  }

  @override
  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    rawParticipantUpdates.add(Map<String, dynamic>.from(data));

    participantUpdates.add(
      _ParticipantUpdate(
        userId: userId,
        rotationOrder: data['rotationOrder'] as int,
      ),
    );
  }

  @override
  void updateModule(Map<String, dynamic> data) {
    moduleUpdates.add(Map<String, dynamic>.from(data));
  }
}

final class _ParticipantUpdate {
  const _ParticipantUpdate({required this.userId, required this.rotationOrder});

  final String userId;
  final int rotationOrder;

  @override
  bool operator ==(Object other) {
    return other is _ParticipantUpdate &&
        other.userId == userId &&
        other.rotationOrder == rotationOrder;
  }

  @override
  int get hashCode => Object.hash(userId, rotationOrder);

  @override
  String toString() {
    return '_ParticipantUpdate('
        'userId: $userId, '
        'rotationOrder: $rotationOrder)';
  }
}
