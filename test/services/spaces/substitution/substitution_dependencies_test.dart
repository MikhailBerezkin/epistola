import 'package:epistola/domain/models/substitution_call_receipt.dart';
import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/services/spaces/substitution/substitution_call_firestore_gateway.dart';
import 'package:epistola/services/spaces/substitution/substitution_dependencies.dart';
import 'package:epistola/services/spaces/substitution/substitution_participant_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epistola/services/spaces/substitution/substitution_work_display_name_firestore_gateway.dart';

void main() {
  group('participant actions dependencies', () {
    test('wires availability updates through firestore gateway', () async {
      final updates = <_Update>[];

      final service = createSubstitutionParticipantActionsService(
        gateway: _participantGateway(updates: updates),
      );

      await service.updateAvailability(
        userId: ' user-1 ',
        availability: SubstitutionAvailability.red,
      );

      expect(updates, hasLength(1));
      expect(updates.single.userId, 'user-1');
      expect(updates.single.data, const {'availability': 'red'});
    });

    test('wires status updates through firestore gateway', () async {
      final updates = <_Update>[];

      final service = createSubstitutionParticipantActionsService(
        gateway: _participantGateway(updates: updates),
      );

      await service.updateStatus(
        userId: 'user-1',
        status: SubstitutionParticipantStatus.vacation,
      );

      expect(updates, hasLength(1));
      expect(updates.single.data, const {'status': 'vacation'});
    });

    test('wires participant removal through firestore gateway', () async {
      final deletedUserIds = <String>[];

      final service = createSubstitutionParticipantActionsService(
        gateway: _participantGateway(deletedUserIds: deletedUserIds),
      );

      await service.removeParticipant(userId: ' user-7 ');

      expect(deletedUserIds, ['user-7']);
    });
  });

  group('work display name dependencies', () {
    test('wires work display name through firestore gateway', () async {
      final updates = <_Update>[];

      final gateway = SubstitutionWorkDisplayNameFirestoreGateway(
        documentUpdater:
            ({
              required String userId,
              required Map<String, dynamic> data,
            }) async {
              updates.add(
                _Update(userId: userId, data: Map<String, dynamic>.from(data)),
              );
            },
      );

      final service = createSubstitutionWorkDisplayNameService(
        gateway: gateway,
      );

      await service.updateWorkDisplayName(
        userId: ' user-1 ',
        workDisplayName: '  Михаил  ',
      );

      expect(updates, [
        const _Update(
          userId: 'user-1',
          data: <String, dynamic>{'workDisplayName': 'Михаил'},
        ),
      ]);
    });

    test('wires empty work display name reset', () async {
      final updates = <_Update>[];

      final gateway = SubstitutionWorkDisplayNameFirestoreGateway(
        documentUpdater:
            ({
              required String userId,
              required Map<String, dynamic> data,
            }) async {
              updates.add(
                _Update(userId: userId, data: Map<String, dynamic>.from(data)),
              );
            },
      );

      final service = createSubstitutionWorkDisplayNameService(
        gateway: gateway,
      );

      await service.updateWorkDisplayName(
        userId: 'user-1',
        workDisplayName: '   ',
      );

      expect(updates, [
        const _Update(
          userId: 'user-1',
          data: <String, dynamic>{'workDisplayName': ''},
        ),
      ]);
    });
  });

  group('call dependencies', () {
    test('wires participant call through firestore gateway', () async {
      final context = _FakeCallTransactionContext(
        moduleData: <String, dynamic>{'nextRotationOrder': 41, 'revision': 7},
        participants: <String, Map<String, dynamic>>{
          'user-1': <String, dynamic>{
            'rotationOrder': 15,
            'availability': 'green',
            'status': 'active',
          },
        },
      );

      final service = createSubstitutionCallService(
        gateway: SubstitutionCallFirestoreGateway(
          _FakeCallTransactionRunner(context),
        ),
      );

      final receipt = await service.callParticipant(userId: 'user-1');

      expect(receipt.userId, 'user-1');
      expect(receipt.revision, 8);

      expect(context.participantUpdates, [
        const _Update(
          userId: 'user-1',
          data: <String, dynamic>{'rotationOrder': 41},
        ),
      ]);

      expect(context.moduleUpdates, [
        <String, dynamic>{
          'nextRotationOrder': 42,
          'revision': 8,
          'lastCall': <String, dynamic>{
            'userId': 'user-1',
            'previousRotationOrder': 15,
            'revision': 8,
          },
        },
      ]);
    });

    test('wires undo through firestore gateway', () async {
      final context = _FakeCallTransactionContext(
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

      final service = createSubstitutionCallService(
        gateway: SubstitutionCallFirestoreGateway(
          _FakeCallTransactionRunner(context),
        ),
      );

      final undone = await service.undoLastCall(
        receipt: const SubstitutionCallReceipt(userId: 'user-1', revision: 8),
      );

      expect(undone, isTrue);

      expect(context.participantUpdates, [
        const _Update(
          userId: 'user-1',
          data: <String, dynamic>{'rotationOrder': 15},
        ),
      ]);

      expect(context.clearLastCallCount, 1);
    });
  });
}

SubstitutionParticipantFirestoreGateway _participantGateway({
  List<_Update>? updates,
  List<String>? deletedUserIds,
}) {
  return SubstitutionParticipantFirestoreGateway(
    documentUpdater:
        ({required String userId, required Map<String, dynamic> data}) async {
          updates?.add(
            _Update(userId: userId, data: Map<String, dynamic>.from(data)),
          );
        },
    documentDeleter: ({required String userId}) async {
      deletedUserIds?.add(userId);
    },
  );
}

final class _FakeCallTransactionRunner
    implements SubstitutionCallTransactionRunner {
  _FakeCallTransactionRunner(this.context);

  final SubstitutionCallTransactionContext context;

  @override
  Future<T> run<T>(
    Future<T> Function(SubstitutionCallTransactionContext context) action,
  ) {
    return action(context);
  }
}

final class _FakeCallTransactionContext
    implements SubstitutionCallTransactionContext {
  _FakeCallTransactionContext({
    required Map<String, dynamic> moduleData,
    required Map<String, Map<String, dynamic>> participants,
  }) : _moduleData = Map<String, dynamic>.from(moduleData),
       _participants = participants.map(
         (userId, data) => MapEntry(userId, Map<String, dynamic>.from(data)),
       );

  final Map<String, dynamic> _moduleData;
  final Map<String, Map<String, dynamic>> _participants;

  final List<Map<String, dynamic>> moduleUpdates = <Map<String, dynamic>>[];

  final List<_Update> participantUpdates = <_Update>[];

  int clearLastCallCount = 0;

  @override
  Future<Map<String, dynamic>?> readModule() async {
    return Map<String, dynamic>.from(_moduleData);
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
  void updateModule(Map<String, dynamic> data) {
    moduleUpdates.add(Map<String, dynamic>.from(data));
  }

  @override
  void updateParticipant({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    participantUpdates.add(
      _Update(userId: userId, data: Map<String, dynamic>.from(data)),
    );
  }

  @override
  void clearLastCall() {
    clearLastCallCount += 1;
  }
}

final class _Update {
  const _Update({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;

  @override
  bool operator ==(Object other) {
    return other is _Update &&
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
