import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/services/spaces/substitution/substitution_dependencies.dart';
import 'package:epistola/services/spaces/substitution/substitution_participant_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wires availability updates through firestore gateway', () async {
    final updates = <_Update>[];

    final service = createSubstitutionParticipantActionsService(
      gateway: _gateway(updates: updates),
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
      gateway: _gateway(updates: updates),
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
      gateway: _gateway(deletedUserIds: deletedUserIds),
    );

    await service.removeParticipant(userId: ' user-7 ');

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
