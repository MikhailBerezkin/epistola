import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/domain/models/substitution_rotation_draft.dart';
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

  test('starts from canonical rotation order', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-c', 30),
      participant('user-a', 10),
      participant('user-b', 20),
    ]);

    expect(draft.currentUserIds, ['user-a', 'user-b', 'user-c']);
    expect(draft.originalUserIds, ['user-a', 'user-b', 'user-c']);
    expect(draft.hasChanges, isFalse);
  });

  test('moves participant one position up', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 10),
      participant('user-b', 20),
      participant('user-c', 30),
    ]);

    final updated = draft.moveUp('user-c');

    expect(updated.currentUserIds, ['user-a', 'user-c', 'user-b']);
    expect(updated.hasChanges, isTrue);
  });

  test('moves participant one position down', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 10),
      participant('user-b', 20),
      participant('user-c', 30),
    ]);

    final updated = draft.moveDown('user-a');

    expect(updated.currentUserIds, ['user-b', 'user-a', 'user-c']);
    expect(updated.hasChanges, isTrue);
  });

  test('first participant cannot move up', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 10),
      participant('user-b', 20),
    ]);

    expect(draft.canMoveUp('user-a'), isFalse);
    expect(draft.moveUp('user-a'), same(draft));
  });

  test('last participant cannot move down', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 10),
      participant('user-b', 20),
    ]);

    expect(draft.canMoveDown('user-b'), isFalse);
    expect(draft.moveDown('user-b'), same(draft));
  });

  test('supports any number of local moves before apply', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 10),
      participant('user-b', 20),
      participant('user-c', 30),
      participant('user-d', 40),
    ]);

    final updated = draft
        .moveUp('user-d')
        .moveUp('user-d')
        .moveDown('user-a')
        .moveDown('user-c');

    expect(updated.currentUserIds, ['user-d', 'user-a', 'user-b', 'user-c']);

    expect(updated.hasChanges, isTrue);
  });

  test('moving back to original order clears hasChanges', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 10),
      participant('user-b', 20),
      participant('user-c', 30),
    ]);

    final updated = draft.moveDown('user-a').moveUp('user-a');

    expect(updated.currentUserIds, ['user-a', 'user-b', 'user-c']);
    expect(updated.hasChanges, isFalse);
  });

  test('normalizes final rotation order without losing participant data', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 100, availability: SubstitutionAvailability.yellow),
      participant(
        'user-b',
        300,
        status: SubstitutionParticipantStatus.vacation,
      ),
      participant('user-c', 900),
    ]);

    final updated = draft.moveUp('user-c');

    final normalized = updated.normalizedParticipants();

    expect(normalized.map((participant) => participant.userId), [
      'user-a',
      'user-c',
      'user-b',
    ]);

    expect(normalized.map((participant) => participant.rotationOrder), [
      0,
      1,
      2,
    ]);

    expect(normalized[0].availability, SubstitutionAvailability.yellow);

    expect(normalized[2].status, SubstitutionParticipantStatus.vacation);
  });

  test('rejects moving participant missing from draft', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 10),
      participant('user-b', 20),
    ]);

    expect(() => draft.moveUp('missing-user'), throwsArgumentError);

    expect(() => draft.moveDown('missing-user'), throwsArgumentError);
  });
  test('active move up skips participant on vacation', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 0),
      participant(
        'vacation-user',
        1,
        status: SubstitutionParticipantStatus.vacation,
      ),
      participant('user-b', 2),
      participant('user-c', 3),
    ]);

    final updated = draft.moveActiveUp('user-b');

    expect(updated.participants.map((item) => item.userId), [
      'user-b',
      'vacation-user',
      'user-a',
      'user-c',
    ]);

    expect(
      updated.participants
          .where((item) => item.isActive)
          .map((item) => item.userId),
      ['user-b', 'user-a', 'user-c'],
    );
  });

  test('active move down skips sick participant', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 0),
      participant('sick-user', 1, status: SubstitutionParticipantStatus.sick),
      participant('user-b', 2),
      participant('user-c', 3),
    ]);

    final updated = draft.moveActiveDown('user-a');

    expect(updated.participants.map((item) => item.userId), [
      'user-b',
      'sick-user',
      'user-a',
      'user-c',
    ]);

    expect(
      updated.participants
          .where((item) => item.isActive)
          .map((item) => item.userId),
      ['user-b', 'user-a', 'user-c'],
    );
  });

  test('first and last active participants respect active boundaries', () {
    final draft = SubstitutionRotationDraft.fromParticipants([
      participant('user-a', 0),
      participant(
        'vacation-user',
        1,
        status: SubstitutionParticipantStatus.vacation,
      ),
      participant('user-b', 2),
    ]);

    expect(draft.canMoveActiveUp('user-a'), isFalse);
    expect(draft.canMoveActiveDown('user-a'), isTrue);

    expect(draft.canMoveActiveUp('user-b'), isTrue);
    expect(draft.canMoveActiveDown('user-b'), isFalse);
  });

  test(
    'active editing keeps inactive participants and normalizes all orders',
    () {
      final draft = SubstitutionRotationDraft.fromParticipants([
        participant('user-a', 10),
        participant(
          'vacation-user',
          30,
          status: SubstitutionParticipantStatus.vacation,
        ),
        participant('user-b', 60),
        participant(
          'sick-user',
          80,
          status: SubstitutionParticipantStatus.sick,
        ),
        participant('user-c', 100),
      ]);

      final normalized = draft
          .moveActiveUp('user-c')
          .moveActiveUp('user-c')
          .normalizedParticipants();

      expect(normalized.map((item) => item.userId), [
        'user-c',
        'vacation-user',
        'user-a',
        'sick-user',
        'user-b',
      ]);

      expect(normalized.map((item) => item.rotationOrder), [0, 1, 2, 3, 4]);

      expect(normalized[1].status, SubstitutionParticipantStatus.vacation);

      expect(normalized[3].status, SubstitutionParticipantStatus.sick);
    },
  );
}
