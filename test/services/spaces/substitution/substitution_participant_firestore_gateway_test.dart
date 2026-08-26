import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/services/spaces/substitution/substitution_participant_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('availability update writes only availability field', () async {
    final updates = <_Update>[];

    final gateway = _gateway(updates: updates);

    await gateway.updateAvailability(
      userId: 'user-1',
      availability: SubstitutionAvailability.yellow,
    );

    expect(updates, hasLength(1));
    expect(updates.single.userId, 'user-1');
    expect(updates.single.data, const {'availability': 'yellow'});

    expect(updates.single.data.containsKey('rotationOrder'), isFalse);
    expect(updates.single.data.containsKey('status'), isFalse);
  });

  test('status update writes only status field', () async {
    final updates = <_Update>[];

    final gateway = _gateway(updates: updates);

    await gateway.updateStatus(
      userId: 'user-1',
      status: SubstitutionParticipantStatus.vacation,
    );

    expect(updates, hasLength(1));
    expect(updates.single.userId, 'user-1');
    expect(updates.single.data, const {'status': 'vacation'});

    expect(updates.single.data.containsKey('rotationOrder'), isFalse);
    expect(updates.single.data.containsKey('availability'), isFalse);
  });

  test('return to active writes only active status', () async {
    final updates = <_Update>[];

    final gateway = _gateway(updates: updates);

    await gateway.updateStatus(
      userId: 'user-1',
      status: SubstitutionParticipantStatus.active,
    );

    expect(updates.single.data, const {'status': 'active'});

    expect(updates.single.data.containsKey('rotationOrder'), isFalse);
  });

  test('sick status writes only sick status', () async {
    final updates = <_Update>[];

    final gateway = _gateway(updates: updates);

    await gateway.updateStatus(
      userId: 'user-1',
      status: SubstitutionParticipantStatus.sick,
    );

    expect(updates.single.data, const {'status': 'sick'});
  });

  test('remove deletes only selected participant document', () async {
    final deletedUserIds = <String>[];

    final gateway = _gateway(deletedUserIds: deletedUserIds);

    await gateway.removeParticipant(userId: 'user-7');

    expect(deletedUserIds, ['user-7']);
  });
}

SubstitutionParticipantFirestoreGateway _gateway({
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

class _Update {
  const _Update({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;
}
