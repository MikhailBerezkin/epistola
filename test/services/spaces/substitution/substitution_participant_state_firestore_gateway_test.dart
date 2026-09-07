import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/services/spaces/substitution/substitution_participant_state_firestore_gateway.dart';
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

    expect(updates.single.data, const <String, dynamic>{
      'availability': 'yellow',
    });

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

    expect(updates.single.data, const <String, dynamic>{'status': 'vacation'});

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

    expect(updates.single.data, const <String, dynamic>{'status': 'active'});

    expect(updates.single.data.containsKey('rotationOrder'), isFalse);
  });

  test('sick status writes only sick status', () async {
    final updates = <_Update>[];

    final gateway = _gateway(updates: updates);

    await gateway.updateStatus(
      userId: 'user-1',
      status: SubstitutionParticipantStatus.sick,
    );

    expect(updates.single.data, const <String, dynamic>{'status': 'sick'});
  });
}

SubstitutionParticipantStateFirestoreGateway _gateway({
  List<_Update>? updates,
}) {
  return SubstitutionParticipantStateFirestoreGateway(
    documentUpdater:
        ({required String userId, required Map<String, dynamic> data}) async {
          updates?.add(
            _Update(userId: userId, data: Map<String, dynamic>.from(data)),
          );
        },
  );
}

class _Update {
  const _Update({required this.userId, required this.data});

  final String userId;
  final Map<String, dynamic> data;
}
