import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/services/spaces/substitution/substitution_participants_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SubstitutionParticipant participant(String userId, int rotationOrder) {
    return SubstitutionParticipant(
      userId: userId,
      rotationOrder: rotationOrder,
    );
  }

  test('watchParticipants returns participants in rotation order', () async {
    final service = SubstitutionParticipantsService(
      participantsWatcher: () => Stream.value([
        participant('user-3', 30),
        participant('user-1', 10),
        participant('user-2', 20),
      ]),
      participantsAdder: (_) async => 0,
    );

    final result = await service.watchParticipants().first;

    expect(result.map((item) => item.userId), ['user-1', 'user-2', 'user-3']);
  });

  test('addParticipants trims ids and removes duplicates', () async {
    List<String>? committedUserIds;

    final service = SubstitutionParticipantsService(
      participantsWatcher: () => const Stream.empty(),
      participantsAdder: (userIds) async {
        committedUserIds = List<String>.from(userIds);
        return userIds.length;
      },
    );

    final addedCount = await service.addParticipants([
      ' user-2 ',
      'user-1',
      'user-2',
    ]);

    expect(committedUserIds, ['user-2', 'user-1']);
    expect(addedCount, 2);
  });

  test('empty selection does not perform a write', () async {
    var writeCalled = false;

    final service = SubstitutionParticipantsService(
      participantsWatcher: () => const Stream.empty(),
      participantsAdder: (userIds) async {
        writeCalled = true;
        return userIds.length;
      },
    );

    final addedCount = await service.addParticipants(const []);

    expect(addedCount, 0);
    expect(writeCalled, isFalse);
  });

  test('rejects empty participant id', () {
    final service = SubstitutionParticipantsService(
      participantsWatcher: () => const Stream.empty(),
      participantsAdder: (_) async => 0,
    );

    expect(() => service.addParticipants(['   ']), throwsArgumentError);
  });

  test('rejects participant id containing slash', () {
    final service = SubstitutionParticipantsService(
      participantsWatcher: () => const Stream.empty(),
      participantsAdder: (_) async => 0,
    );

    expect(() => service.addParticipants(['user/1']), throwsArgumentError);
  });
}
