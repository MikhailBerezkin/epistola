import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/domain/models/substitution_rotation_draft.dart';
import 'package:epistola/services/spaces/substitution/substitution_rotation_edit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SubstitutionParticipant participant(
    String userId,
    int rotationOrder, {
    SubstitutionAvailability availability = SubstitutionAvailability.green,
    SubstitutionParticipantStatus status = SubstitutionParticipantStatus.active,
  }) {
    return SubstitutionParticipant(
      userId: userId,
      rotationOrder: rotationOrder,
      availability: availability,
      status: status,
    );
  }

  test('begin editing returns valid baseline', () async {
    final service = SubstitutionRotationEditService(
      baselineLoader: () async {
        return const SubstitutionRotationEditBaseline(
          nextRotationOrder: 40,
          revision: 12,
        );
      },
      rotationWriter:
          ({
            required originalParticipants,
            required participants,
            required expectedNextRotationOrder,
            required expectedRevision,
          }) async {
            return true;
          },
    );

    final baseline = await service.beginEditing();

    expect(baseline.nextRotationOrder, 40);
    expect(baseline.revision, 12);
  });

  test('begin editing rejects negative next rotation order', () async {
    final service = SubstitutionRotationEditService(
      baselineLoader: () async {
        return const SubstitutionRotationEditBaseline(
          nextRotationOrder: -1,
          revision: 12,
        );
      },
      rotationWriter:
          ({
            required originalParticipants,
            required participants,
            required expectedNextRotationOrder,
            required expectedRevision,
          }) async {
            return true;
          },
    );

    expect(service.beginEditing, throwsStateError);
  });

  test('begin editing rejects negative revision', () async {
    final service = SubstitutionRotationEditService(
      baselineLoader: () async {
        return const SubstitutionRotationEditBaseline(
          nextRotationOrder: 40,
          revision: -1,
        );
      },
      rotationWriter:
          ({
            required originalParticipants,
            required participants,
            required expectedNextRotationOrder,
            required expectedRevision,
          }) async {
            return true;
          },
    );

    expect(service.beginEditing, throwsStateError);
  });

  test('unchanged draft does not write', () async {
    var writeCount = 0;

    final service = SubstitutionRotationEditService(
      baselineLoader: () async {
        return const SubstitutionRotationEditBaseline(
          nextRotationOrder: 30,
          revision: 5,
        );
      },
      rotationWriter:
          ({
            required originalParticipants,
            required participants,
            required expectedNextRotationOrder,
            required expectedRevision,
          }) async {
            writeCount++;
            return true;
          },
    );

    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 10),
      participant('user-b', 20),
    ]);

    final result = await service.apply(
      draft: draft,
      baseline: const SubstitutionRotationEditBaseline(
        nextRotationOrder: 30,
        revision: 5,
      ),
    );

    expect(result, SubstitutionRotationEditApplyResult.noChanges);
    expect(writeCount, 0);
  });

  test('apply writes final normalized order once', () async {
    List<SubstitutionParticipant>? writtenOriginal;
    List<SubstitutionParticipant>? writtenParticipants;
    int? writtenNextRotationOrder;
    int? writtenRevision;

    final service = SubstitutionRotationEditService(
      baselineLoader: () async {
        return const SubstitutionRotationEditBaseline(
          nextRotationOrder: 90,
          revision: 7,
        );
      },
      rotationWriter:
          ({
            required originalParticipants,
            required participants,
            required expectedNextRotationOrder,
            required expectedRevision,
          }) async {
            writtenOriginal = originalParticipants;
            writtenParticipants = participants;
            writtenNextRotationOrder = expectedNextRotationOrder;
            writtenRevision = expectedRevision;

            return true;
          },
    );

    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 10),
      participant('user-b', 30),
      participant('user-c', 80),
    ]).moveUp('user-c');

    final result = await service.apply(
      draft: draft,
      baseline: const SubstitutionRotationEditBaseline(
        nextRotationOrder: 90,
        revision: 7,
      ),
    );

    expect(result, SubstitutionRotationEditApplyResult.applied);

    expect(writtenOriginal!.map((item) => item.userId), [
      'user-a',
      'user-b',
      'user-c',
    ]);

    expect(writtenOriginal!.map((item) => item.rotationOrder), [10, 30, 80]);

    expect(writtenParticipants!.map((item) => item.userId), [
      'user-a',
      'user-c',
      'user-b',
    ]);

    expect(writtenParticipants!.map((item) => item.rotationOrder), [0, 1, 2]);

    expect(writtenNextRotationOrder, 90);
    expect(writtenRevision, 7);
  });

  test('apply preserves participant state while changing order', () async {
    List<SubstitutionParticipant>? writtenParticipants;

    final service = SubstitutionRotationEditService(
      baselineLoader: () async {
        return const SubstitutionRotationEditBaseline(
          nextRotationOrder: 100,
          revision: 8,
        );
      },
      rotationWriter:
          ({
            required originalParticipants,
            required participants,
            required expectedNextRotationOrder,
            required expectedRevision,
          }) async {
            writtenParticipants = participants;
            return true;
          },
    );

    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 20, availability: SubstitutionAvailability.yellow),
      participant('user-b', 80, status: SubstitutionParticipantStatus.vacation),
    ]).moveDown('user-a');

    await service.apply(
      draft: draft,
      baseline: const SubstitutionRotationEditBaseline(
        nextRotationOrder: 100,
        revision: 8,
      ),
    );

    expect(writtenParticipants![0].userId, 'user-b');
    expect(
      writtenParticipants![0].status,
      SubstitutionParticipantStatus.vacation,
    );

    expect(writtenParticipants![1].userId, 'user-a');
    expect(
      writtenParticipants![1].availability,
      SubstitutionAvailability.yellow,
    );
  });

  test('writer conflict is returned as conflict result', () async {
    final service = SubstitutionRotationEditService(
      baselineLoader: () async {
        return const SubstitutionRotationEditBaseline(
          nextRotationOrder: 50,
          revision: 3,
        );
      },
      rotationWriter:
          ({
            required originalParticipants,
            required participants,
            required expectedNextRotationOrder,
            required expectedRevision,
          }) async {
            return false;
          },
    );

    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 10),
      participant('user-b', 20),
    ]).moveDown('user-a');

    final result = await service.apply(
      draft: draft,
      baseline: const SubstitutionRotationEditBaseline(
        nextRotationOrder: 50,
        revision: 3,
      ),
    );

    expect(result, SubstitutionRotationEditApplyResult.conflict);
  });
}
