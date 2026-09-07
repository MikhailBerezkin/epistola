import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/services/spaces/substitution/substitution_rotation_membership_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds truly new participant at front and shifts old anchors', () async {
    final baseline = _baseline(
      nextRotationOrder: 100,
      participants: [_participant('andrey', 10), _participant('viktor', 20)],
    );

    final context = _Context(
      moduleData: {'nextRotationOrder': 100, 'revision': 7},
      participants: {'andrey': _data(10), 'viktor': _data(20)},
    );

    final gateway = _gateway(
      baselineLoader: () async => baseline,
      contexts: [context],
    );

    final count = await gateway.addParticipants(const ['stepan']);

    expect(count, 1);

    expect(context.creates, const [
      _Write(
        userId: 'stepan',
        data: {'rotationOrder': 0, 'availability': 'green', 'status': 'active'},
      ),
    ]);

    expect(context.updates, const [
      _Write(userId: 'andrey', data: {'rotationOrder': 11}),
      _Write(userId: 'viktor', data: {'rotationOrder': 21}),
    ]);

    expect(context.moduleWrites, const [
      {'nextRotationOrder': 101},
    ]);
  });

  test('restores removed participant at preserved anchor', () async {
    final baseline = _baseline(
      nextRotationOrder: 100,
      participants: [
        _participant('andrey', 10),
        _participant(
          'boris',
          20,
          status: SubstitutionParticipantStatus.removed,
        ),
        _participant('viktor', 30),
      ],
    );

    final context = _Context(
      moduleData: {'nextRotationOrder': 100, 'revision': 7},
      participants: {
        'andrey': _data(10),
        'boris': _data(20, status: 'removed'),
        'viktor': _data(30),
      },
    );

    final gateway = _gateway(
      baselineLoader: () async => baseline,
      contexts: [context],
    );

    final count = await gateway.addParticipants(const ['boris']);

    expect(count, 1);

    expect(context.creates, isEmpty);

    expect(context.updates, const [
      _Write(userId: 'boris', data: {'status': 'active'}),
    ]);

    expect(context.moduleWrites, const [
      {'nextRotationOrder': 101},
    ]);
  });
  test(
    'new plus restored participant advances marker only by new count',
    () async {
      final baseline = _baseline(
        nextRotationOrder: 100,
        participants: [
          _participant('andrey', 10),
          _participant(
            'boris',
            20,
            status: SubstitutionParticipantStatus.removed,
          ),
        ],
      );

      final context = _Context(
        moduleData: {'nextRotationOrder': 100, 'revision': 7},
        participants: {
          'andrey': _data(10),
          'boris': _data(20, status: 'removed'),
        },
      );

      final gateway = _gateway(
        baselineLoader: () async => baseline,
        contexts: [context],
      );

      final count = await gateway.addParticipants(const ['stepan', 'boris']);

      expect(count, 2);

      expect(context.moduleWrites, const [
        {'nextRotationOrder': 101},
      ]);
    },
  );

  test(
    'new participant goes first and restored anchor shifts with old rotation',
    () async {
      final baseline = _baseline(
        nextRotationOrder: 100,
        participants: [
          _participant('andrey', 10),
          _participant(
            'boris',
            20,
            status: SubstitutionParticipantStatus.removed,
          ),
          _participant('viktor', 30),
        ],
      );

      final context = _Context(
        moduleData: {'nextRotationOrder': 100, 'revision': 7},
        participants: {
          'andrey': _data(10),
          'boris': _data(20, status: 'removed'),
          'viktor': _data(30),
        },
      );

      final gateway = _gateway(
        baselineLoader: () async => baseline,
        contexts: [context],
      );

      final count = await gateway.addParticipants(const ['stepan', 'boris']);

      expect(count, 2);

      expect(context.creates, const [
        _Write(
          userId: 'stepan',
          data: {
            'rotationOrder': 0,
            'availability': 'green',
            'status': 'active',
          },
        ),
      ]);

      expect(context.updates, const [
        _Write(userId: 'andrey', data: {'rotationOrder': 11}),
        _Write(
          userId: 'boris',
          data: {'rotationOrder': 21, 'status': 'active'},
        ),
        _Write(userId: 'viktor', data: {'rotationOrder': 31}),
      ]);

      expect(context.moduleWrites, const [
        {'nextRotationOrder': 101},
      ]);
    },
  );

  test('existing participant does not gain new-entry priority', () async {
    final runner = _FailingTransactionRunner();

    final gateway = SubstitutionRotationMembershipFirestoreGateway(
      baselineLoader: () async {
        return _baseline(
          nextRotationOrder: 100,
          participants: [
            _participant('andrey', 10),
            _participant('stepan', 20),
          ],
        );
      },
      transactionRunner: runner,
    );

    final count = await gateway.addParticipants(const ['stepan']);

    expect(count, 0);
    expect(runner.runCount, 0);
  });

  test('adds several truly new participants in requested order', () async {
    final baseline = _baseline(
      nextRotationOrder: 100,
      participants: [_participant('andrey', 10)],
    );

    final context = _Context(
      moduleData: {'nextRotationOrder': 100, 'revision': 7},
      participants: {'andrey': _data(10)},
    );

    final gateway = _gateway(
      baselineLoader: () async => baseline,
      contexts: [context],
    );

    final count = await gateway.addParticipants(const ['stepan', 'mikhail']);

    expect(count, 2);

    expect(context.creates, const [
      _Write(
        userId: 'stepan',
        data: {'rotationOrder': 0, 'availability': 'green', 'status': 'active'},
      ),
      _Write(
        userId: 'mikhail',
        data: {'rotationOrder': 1, 'availability': 'green', 'status': 'active'},
      ),
    ]);

    expect(context.updates, const [
      _Write(userId: 'andrey', data: {'rotationOrder': 12}),
    ]);

    expect(context.moduleWrites, const [
      {'nextRotationOrder': 102},
    ]);
  });

  test('rejects participant change while call is pending', () async {
    final runner = _FailingTransactionRunner();

    final gateway = SubstitutionRotationMembershipFirestoreGateway(
      baselineLoader: () async {
        return _baseline(
          nextRotationOrder: 100,
          hasPendingCall: true,
          participants: [_participant('andrey', 10)],
        );
      },
      transactionRunner: runner,
    );

    await expectLater(
      gateway.addParticipants(const ['stepan']),
      throwsStateError,
    );

    expect(runner.runCount, 0);
  });

  test('retries with fresh baseline after module conflict', () async {
    final baselines = [
      _baseline(
        nextRotationOrder: 100,
        participants: [_participant('andrey', 10)],
      ),
      _baseline(
        nextRotationOrder: 101,
        participants: [_participant('andrey', 10)],
      ),
    ];

    var baselineIndex = 0;

    final firstContext = _Context(
      moduleData: {'nextRotationOrder': 101, 'revision': 7},
      participants: {'andrey': _data(10)},
    );

    final secondContext = _Context(
      moduleData: {'nextRotationOrder': 101, 'revision': 7},
      participants: {'andrey': _data(10)},
    );

    final gateway = SubstitutionRotationMembershipFirestoreGateway(
      baselineLoader: () async {
        return baselines[baselineIndex++];
      },
      transactionRunner: _QueuedTransactionRunner([
        firstContext,
        secondContext,
      ]),
    );

    final count = await gateway.addParticipants(const ['stepan']);

    expect(count, 1);

    expect(firstContext.creates, isEmpty);

    expect(secondContext.creates, hasLength(1));

    expect(secondContext.moduleWrites, const [
      {'nextRotationOrder': 102},
    ]);
  });

  test('fails safely after repeated participant order conflicts', () async {
    final baseline = _baseline(
      nextRotationOrder: 100,
      participants: [_participant('andrey', 10)],
    );

    final contexts = List.generate(3, (_) {
      return _Context(
        moduleData: {'nextRotationOrder': 100, 'revision': 7},
        participants: {'andrey': _data(11)},
      );
    });

    final gateway = SubstitutionRotationMembershipFirestoreGateway(
      baselineLoader: () async => baseline,
      transactionRunner: _QueuedTransactionRunner(contexts),
    );

    await expectLater(
      gateway.addParticipants(const ['stepan']),
      throwsStateError,
    );

    for (final context in contexts) {
      expect(context.creates, isEmpty);
      expect(context.updates, isEmpty);
      expect(context.moduleWrites, isEmpty);
    }
  });

  test('creates first participant and substitution module together', () async {
    const baseline = SubstitutionParticipantsBaseline(
      moduleExists: false,
      nextRotationOrder: 0,
      revision: 0,
      participants: <SubstitutionParticipant>[],
      hasPendingCall: false,
    );

    final context = _Context(moduleData: null, participants: const {});

    final gateway = _gateway(
      baselineLoader: () async => baseline,
      contexts: [context],
    );

    final count = await gateway.addParticipants(const ['stepan']);

    expect(count, 1);

    expect(context.creates, const [
      _Write(
        userId: 'stepan',
        data: {'rotationOrder': 0, 'availability': 'green', 'status': 'active'},
      ),
    ]);

    expect(context.moduleWrites, const [
      {'nextRotationOrder': 1},
    ]);
  });

  test(
    'remove preserves rotation anchor and advances mutation marker',
    () async {
      final baseline = _baseline(
        nextRotationOrder: 100,
        participants: [
          _participant('andrey', 10),
          _participant('boris', 20),
          _participant('viktor', 30),
        ],
      );

      final context = _Context(
        moduleData: {'nextRotationOrder': 100, 'revision': 7},
        participants: {
          'andrey': _data(10),
          'boris': _data(20),
          'viktor': _data(30),
        },
      );

      final gateway = _gateway(
        baselineLoader: () async => baseline,
        contexts: [context],
      );

      await gateway.removeParticipant(userId: ' boris ');

      expect(context.updates, const [
        _Write(userId: 'boris', data: {'status': 'removed'}),
      ]);

      expect(context.updates.single.data.containsKey('rotationOrder'), isFalse);

      expect(context.moduleWrites, const [
        {'nextRotationOrder': 101},
      ]);

      expect(context.creates, isEmpty);
    },
  );

  test('already removed participant is an idempotent no-op', () async {
    final runner = _FailingTransactionRunner();

    final gateway = SubstitutionRotationMembershipFirestoreGateway(
      baselineLoader: () async {
        return _baseline(
          nextRotationOrder: 100,
          participants: [
            _participant(
              'boris',
              20,
              status: SubstitutionParticipantStatus.removed,
            ),
          ],
        );
      },
      transactionRunner: runner,
    );

    await gateway.removeParticipant(userId: 'boris');

    expect(runner.runCount, 0);
  });

  test('remove is rejected while call is pending', () async {
    final runner = _FailingTransactionRunner();

    final gateway = SubstitutionRotationMembershipFirestoreGateway(
      baselineLoader: () async {
        return _baseline(
          nextRotationOrder: 100,
          hasPendingCall: true,
          participants: [_participant('boris', 20)],
        );
      },
      transactionRunner: runner,
    );

    await expectLater(
      gateway.removeParticipant(userId: 'boris'),
      throwsStateError,
    );

    expect(runner.runCount, 0);
  });

  test('remove retries after concurrent queue mutation', () async {
    final baselines = [
      _baseline(
        nextRotationOrder: 100,
        participants: [_participant('boris', 20)],
      ),
      _baseline(
        nextRotationOrder: 101,
        participants: [_participant('boris', 20)],
      ),
    ];

    var baselineIndex = 0;

    final firstContext = _Context(
      moduleData: {'nextRotationOrder': 101, 'revision': 7},
      participants: {'boris': _data(20)},
    );

    final secondContext = _Context(
      moduleData: {'nextRotationOrder': 101, 'revision': 7},
      participants: {'boris': _data(20)},
    );

    final gateway = SubstitutionRotationMembershipFirestoreGateway(
      baselineLoader: () async {
        return baselines[baselineIndex++];
      },
      transactionRunner: _QueuedTransactionRunner([
        firstContext,
        secondContext,
      ]),
    );

    await gateway.removeParticipant(userId: 'boris');

    expect(firstContext.updates, isEmpty);
    expect(firstContext.moduleWrites, isEmpty);

    expect(secondContext.updates, const [
      _Write(userId: 'boris', data: {'status': 'removed'}),
    ]);

    expect(secondContext.moduleWrites, const [
      {'nextRotationOrder': 102},
    ]);
  });

  test('remove rejects participant missing from rotation', () async {
    final runner = _FailingTransactionRunner();

    final gateway = SubstitutionRotationMembershipFirestoreGateway(
      baselineLoader: () async {
        return _baseline(
          nextRotationOrder: 100,
          participants: [_participant('andrey', 10)],
        );
      },
      transactionRunner: runner,
    );

    await expectLater(
      gateway.removeParticipant(userId: 'boris'),
      throwsStateError,
    );

    expect(runner.runCount, 0);
  });
}

SubstitutionParticipantsBaseline _baseline({
  required int nextRotationOrder,
  required List<SubstitutionParticipant> participants,
  bool hasPendingCall = false,
}) {
  return SubstitutionParticipantsBaseline(
    moduleExists: true,
    nextRotationOrder: nextRotationOrder,
    revision: 7,
    participants: participants,
    hasPendingCall: hasPendingCall,
  );
}

SubstitutionParticipant _participant(
  String userId,
  int rotationOrder, {
  SubstitutionParticipantStatus status = SubstitutionParticipantStatus.active,
}) {
  return SubstitutionParticipant(
    userId: userId,
    rotationOrder: rotationOrder,
    status: status,
  );
}

Map<String, dynamic> _data(int rotationOrder, {String status = 'active'}) {
  return <String, dynamic>{
    'rotationOrder': rotationOrder,
    'availability': 'green',
    'status': status,
  };
}

SubstitutionRotationMembershipFirestoreGateway _gateway({
  required SubstitutionParticipantsBaselineLoader baselineLoader,
  required List<_Context> contexts,
}) {
  return SubstitutionRotationMembershipFirestoreGateway(
    baselineLoader: baselineLoader,
    transactionRunner: _QueuedTransactionRunner(contexts),
  );
}

final class _QueuedTransactionRunner
    implements SubstitutionParticipantsTransactionRunner {
  _QueuedTransactionRunner(this.contexts);

  final List<_Context> contexts;

  int runCount = 0;

  @override
  Future<T> run<T>(
    Future<T> Function(SubstitutionParticipantsTransactionContext context)
    action,
  ) {
    final context = contexts[runCount];

    runCount++;

    return action(context);
  }
}

final class _FailingTransactionRunner
    implements SubstitutionParticipantsTransactionRunner {
  int runCount = 0;

  @override
  Future<T> run<T>(
    Future<T> Function(SubstitutionParticipantsTransactionContext context)
    action,
  ) {
    runCount++;

    throw StateError('Transaction must not run.');
  }
}

final class _Context implements SubstitutionParticipantsTransactionContext {
  _Context({
    required Map<String, dynamic>? moduleData,
    required Map<String, Map<String, dynamic>> participants,
  }) : _moduleData = moduleData == null
           ? null
           : Map<String, dynamic>.from(moduleData),
       _participants = participants.map((userId, data) {
         return MapEntry(userId, Map<String, dynamic>.from(data));
       });

  final Map<String, dynamic>? _moduleData;

  final Map<String, Map<String, dynamic>> _participants;

  final List<_Write> creates = <_Write>[];

  final List<_Write> updates = <_Write>[];

  final List<Map<String, dynamic>> moduleWrites = <Map<String, dynamic>>[];

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
    final data = _participants[userId];

    if (data == null) {
      return null;
    }

    return Map<String, dynamic>.from(data);
  }

  @override
  void createParticipant({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    creates.add(_Write(userId: userId, data: Map<String, dynamic>.from(data)));
  }

  @override
  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    updates.add(_Write(userId: userId, data: Map<String, dynamic>.from(data)));
  }

  @override
  void setModule(Map<String, dynamic> data) {
    moduleWrites.add(Map<String, dynamic>.from(data));
  }
}

final class _Write {
  const _Write({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;

  @override
  bool operator ==(Object other) {
    return other is _Write &&
        other.userId == userId &&
        _mapEquals(other.data, data);
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      Object.hashAll(
        data.entries.map((entry) {
          return Object.hash(entry.key, entry.value);
        }),
      ),
    );
  }
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
