import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/services/spaces/substitution/substitution_participant_actions_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes participant availability', () async {
    String? writtenUserId;
    SubstitutionAvailability? writtenAvailability;

    final service = SubstitutionParticipantActionsService(
      availabilityWriter:
          ({
            required String userId,
            required SubstitutionAvailability availability,
          }) async {
            writtenUserId = userId;
            writtenAvailability = availability;
          },
      statusWriter:
          ({
            required String userId,
            required SubstitutionParticipantStatus status,
          }) async {},
      participantRemover: ({required String userId}) async {},
    );

    await service.updateAvailability(
      userId: ' user-1 ',
      availability: SubstitutionAvailability.red,
    );

    expect(writtenUserId, 'user-1');
    expect(writtenAvailability, SubstitutionAvailability.red);
  });

  test('writes vacation status without touching rotation order', () async {
    String? writtenUserId;
    SubstitutionParticipantStatus? writtenStatus;

    final service = SubstitutionParticipantActionsService(
      availabilityWriter:
          ({
            required String userId,
            required SubstitutionAvailability availability,
          }) async {},
      statusWriter:
          ({
            required String userId,
            required SubstitutionParticipantStatus status,
          }) async {
            writtenUserId = userId;
            writtenStatus = status;
          },
      participantRemover: ({required String userId}) async {},
    );

    await service.updateStatus(
      userId: 'user-1',
      status: SubstitutionParticipantStatus.vacation,
    );

    expect(writtenUserId, 'user-1');
    expect(writtenStatus, SubstitutionParticipantStatus.vacation);
  });

  test('writes sick status', () async {
    SubstitutionParticipantStatus? writtenStatus;

    final service = SubstitutionParticipantActionsService(
      availabilityWriter:
          ({
            required String userId,
            required SubstitutionAvailability availability,
          }) async {},
      statusWriter:
          ({
            required String userId,
            required SubstitutionParticipantStatus status,
          }) async {
            writtenStatus = status;
          },
      participantRemover: ({required String userId}) async {},
    );

    await service.updateStatus(
      userId: 'user-1',
      status: SubstitutionParticipantStatus.sick,
    );

    expect(writtenStatus, SubstitutionParticipantStatus.sick);
  });

  test('writes active status when participant returns to list', () async {
    SubstitutionParticipantStatus? writtenStatus;

    final service = SubstitutionParticipantActionsService(
      availabilityWriter:
          ({
            required String userId,
            required SubstitutionAvailability availability,
          }) async {},
      statusWriter:
          ({
            required String userId,
            required SubstitutionParticipantStatus status,
          }) async {
            writtenStatus = status;
          },
      participantRemover: ({required String userId}) async {},
    );

    await service.updateStatus(
      userId: 'user-1',
      status: SubstitutionParticipantStatus.active,
    );

    expect(writtenStatus, SubstitutionParticipantStatus.active);
  });

  test('removes participant from substitution space', () async {
    String? removedUserId;

    final service = SubstitutionParticipantActionsService(
      availabilityWriter:
          ({
            required String userId,
            required SubstitutionAvailability availability,
          }) async {},
      statusWriter:
          ({
            required String userId,
            required SubstitutionParticipantStatus status,
          }) async {},
      participantRemover: ({required String userId}) async {
        removedUserId = userId;
      },
    );

    await service.removeParticipant(userId: ' user-1 ');

    expect(removedUserId, 'user-1');
  });

  test('rejects empty user id', () {
    final service = _service();

    expect(
      () => service.updateAvailability(
        userId: '   ',
        availability: SubstitutionAvailability.green,
      ),
      throwsArgumentError,
    );
  });

  test('rejects user id containing slash', () {
    final service = _service();

    expect(
      () => service.updateStatus(
        userId: 'user/1',
        status: SubstitutionParticipantStatus.sick,
      ),
      throwsArgumentError,
    );
  });
}

SubstitutionParticipantActionsService _service() {
  return SubstitutionParticipantActionsService(
    availabilityWriter:
        ({
          required String userId,
          required SubstitutionAvailability availability,
        }) async {},
    statusWriter:
        ({
          required String userId,
          required SubstitutionParticipantStatus status,
        }) async {},
    participantRemover: ({required String userId}) async {},
  );
}
