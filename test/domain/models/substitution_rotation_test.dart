import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/domain/models/substitution_rotation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SubstitutionParticipant participant(
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

  group('SubstitutionRotation', () {
    test('orders participants by rotation order', () {
      final result = SubstitutionRotation.ordered([
        participant('user-3', 30),
        participant('user-1', 10),
        participant('user-2', 20),
      ]);

      expect(result.map((item) => item.userId), ['user-1', 'user-2', 'user-3']);
    });

    test('active excludes vacation and sick participants', () {
      final result = SubstitutionRotation.active([
        participant('user-1', 10),
        participant(
          'user-2',
          20,
          status: SubstitutionParticipantStatus.vacation,
        ),
        participant('user-3', 30, status: SubstitutionParticipantStatus.sick),
        participant('user-4', 40),
      ]);

      expect(result.map((item) => item.userId), ['user-1', 'user-4']);
    });

    test('called participant moves to the end of rotation', () {
      final result = SubstitutionRotation.moveCalledParticipantToEnd(
        participants: [
          participant('ivanov', 10),
          participant('petrov', 20),
          participant('sidorov', 30),
        ],
        userId: 'ivanov',
      );

      expect(result.map((item) => item.userId), [
        'petrov',
        'sidorov',
        'ivanov',
      ]);

      expect(
        result.singleWhere((item) => item.userId == 'ivanov').rotationOrder,
        31,
      );
    });

    test('several calls rotate the list in a circle', () {
      var result = [
        participant('ivanov', 10),
        participant('petrov', 20),
        participant('sidorov', 30),
      ];

      result = SubstitutionRotation.moveCalledParticipantToEnd(
        participants: result,
        userId: 'ivanov',
      );

      result = SubstitutionRotation.moveCalledParticipantToEnd(
        participants: result,
        userId: 'petrov',
      );

      expect(result.map((item) => item.userId), [
        'sidorov',
        'ivanov',
        'petrov',
      ]);
    });

    test(
      'vacation participant keeps position while active rotation moves past it',
      () {
        var result = [
          participant('ivanov', 10),
          participant(
            'petrov',
            20,
            status: SubstitutionParticipantStatus.vacation,
          ),
          participant('sidorov', 30),
          participant('kozlov', 40),
        ];

        result = SubstitutionRotation.moveCalledParticipantToEnd(
          participants: result,
          userId: 'ivanov',
        );

        expect(SubstitutionRotation.active(result).map((item) => item.userId), [
          'sidorov',
          'kozlov',
          'ivanov',
        ]);

        final petrov = result.singleWhere((item) => item.userId == 'petrov');

        expect(petrov.rotationOrder, 20);
        expect(petrov.status, SubstitutionParticipantStatus.vacation);
      },
    );

    test(
      'returning vacation participant appears where rotation naturally moved it',
      () {
        var result = [
          participant('ivanov', 10),
          participant(
            'petrov',
            20,
            status: SubstitutionParticipantStatus.vacation,
          ),
          participant('sidorov', 30),
          participant('kozlov', 40),
        ];

        result = SubstitutionRotation.moveCalledParticipantToEnd(
          participants: result,
          userId: 'ivanov',
        );

        result = SubstitutionRotation.moveCalledParticipantToEnd(
          participants: result,
          userId: 'sidorov',
        );

        final petrovIndex = result.indexWhere(
          (item) => item.userId == 'petrov',
        );

        result[petrovIndex] = result[petrovIndex].withStatus(
          SubstitutionParticipantStatus.active,
        );

        result = SubstitutionRotation.ordered(result);

        expect(result.map((item) => item.userId), [
          'petrov',
          'kozlov',
          'ivanov',
          'sidorov',
        ]);

        expect(
          result.singleWhere((item) => item.userId == 'petrov').rotationOrder,
          20,
        );
      },
    );

    test(
      'removed participant keeps hidden anchor while active rotation moves past it',
      () {
        var result = [
          participant('andrey', 10),
          participant(
            'boris',
            20,
            status: SubstitutionParticipantStatus.removed,
          ),
          participant('stepan', 30),
          participant('viktor', 40),
        ];

        result = SubstitutionRotation.moveCalledParticipantToEnd(
          participants: result,
          userId: 'andrey',
        );

        expect(SubstitutionRotation.active(result).map((item) => item.userId), [
          'stepan',
          'viktor',
          'andrey',
        ]);

        final boris = result.singleWhere((item) => item.userId == 'boris');

        expect(boris.rotationOrder, 20);
        expect(boris.status, SubstitutionParticipantStatus.removed);
      },
    );

    test(
      'removed participant naturally reaches top while active users are called',
      () {
        var result = [
          participant('andrey', 10),
          participant(
            'boris',
            20,
            status: SubstitutionParticipantStatus.removed,
          ),
          participant('stepan', 30),
          participant('viktor', 40),
        ];

        result = SubstitutionRotation.moveCalledParticipantToEnd(
          participants: result,
          userId: 'andrey',
        );

        result = SubstitutionRotation.moveCalledParticipantToEnd(
          participants: result,
          userId: 'stepan',
        );

        expect(result.map((item) => item.userId), [
          'boris',
          'viktor',
          'andrey',
          'stepan',
        ]);

        expect(SubstitutionRotation.active(result).map((item) => item.userId), [
          'viktor',
          'andrey',
          'stepan',
        ]);
      },
    );

    test(
      'restoring removed participant returns it at current hidden anchor',
      () {
        var result = [
          participant('andrey', 10),
          participant(
            'boris',
            20,
            status: SubstitutionParticipantStatus.removed,
          ),
          participant('stepan', 30),
          participant('viktor', 40),
        ];

        result = SubstitutionRotation.moveCalledParticipantToEnd(
          participants: result,
          userId: 'andrey',
        );

        result = SubstitutionRotation.moveCalledParticipantToEnd(
          participants: result,
          userId: 'stepan',
        );

        final borisIndex = result.indexWhere((item) => item.userId == 'boris');

        result[borisIndex] = result[borisIndex].withStatus(
          SubstitutionParticipantStatus.active,
        );

        result = SubstitutionRotation.ordered(result);

        expect(result.map((item) => item.userId), [
          'boris',
          'viktor',
          'andrey',
          'stepan',
        ]);

        expect(result.first.rotationOrder, 20);
      },
    );

    test('inactive participant cannot be called', () {
      expect(
        () => SubstitutionRotation.moveCalledParticipantToEnd(
          participants: [
            participant(
              'ivanov',
              10,
              status: SubstitutionParticipantStatus.sick,
            ),
            participant('petrov', 20),
          ],
          userId: 'ivanov',
        ),
        throwsStateError,
      );
    });
    test('call participant returns data required for undo', () {
      final move = SubstitutionRotation.callParticipant(
        participants: [
          participant('ivanov', 10),
          participant('petrov', 20),
          participant('sidorov', 30),
        ],
        userId: 'ivanov',
      );

      expect(move.userId, 'ivanov');
      expect(move.previousRotationOrder, 10);

      expect(move.participants.map((item) => item.userId), [
        'petrov',
        'sidorov',
        'ivanov',
      ]);
    });

    test('undo restores called participant to previous position', () {
      final move = SubstitutionRotation.callParticipant(
        participants: [
          participant('ivanov', 10),
          participant('petrov', 20),
          participant('sidorov', 30),
        ],
        userId: 'ivanov',
      );

      final restored = SubstitutionRotation.undoCall(move);

      expect(restored.map((item) => item.userId), [
        'ivanov',
        'petrov',
        'sidorov',
      ]);

      expect(
        restored.singleWhere((item) => item.userId == 'ivanov').rotationOrder,
        10,
      );
    });

    test('undo applies only to the latest call move', () {
      final firstMove = SubstitutionRotation.callParticipant(
        participants: [
          participant('ivanov', 10),
          participant('petrov', 20),
          participant('sidorov', 30),
        ],
        userId: 'ivanov',
      );

      final secondMove = SubstitutionRotation.callParticipant(
        participants: firstMove.participants,
        userId: 'petrov',
      );

      expect(secondMove.participants.map((item) => item.userId), [
        'sidorov',
        'ivanov',
        'petrov',
      ]);

      final restored = SubstitutionRotation.undoCall(secondMove);

      expect(restored.map((item) => item.userId), [
        'petrov',
        'sidorov',
        'ivanov',
      ]);
    });
    test('truly new participant is added at the front', () {
      final result = SubstitutionRotation.addOrRestoreParticipants(
        participants: [
          participant('andrey', 10),
          participant('viktor', 20),
          participant('gleb', 30),
        ],
        userIds: const ['stepan'],
      );

      expect(result.participants.map((item) => item.userId), [
        'stepan',
        'andrey',
        'viktor',
        'gleb',
      ]);

      expect(result.participants.map((item) => item.rotationOrder), [
        0,
        11,
        21,
        31,
      ]);

      expect(result.addedCount, 1);
      expect(result.createdUserIds, {'stepan'});
      expect(result.restoredUserIds, isEmpty);
    });

    test('removed participant restores at preserved anchor', () {
      final result = SubstitutionRotation.addOrRestoreParticipants(
        participants: [
          participant('andrey', 10),
          participant(
            'boris',
            20,
            status: SubstitutionParticipantStatus.removed,
          ),
          participant('viktor', 30),
        ],
        userIds: const ['boris'],
      );

      expect(result.participants.map((item) => item.userId), [
        'andrey',
        'boris',
        'viktor',
      ]);

      final boris = result.participants.singleWhere(
        (item) => item.userId == 'boris',
      );

      expect(boris.rotationOrder, 20);
      expect(boris.status, SubstitutionParticipantStatus.active);

      expect(result.addedCount, 1);
      expect(result.createdUserIds, isEmpty);
      expect(result.restoredUserIds, {'boris'});
    });

    test(
      'new participant goes first while removed participant keeps old relative anchor',
      () {
        final result = SubstitutionRotation.addOrRestoreParticipants(
          participants: [
            participant('andrey', 10),
            participant(
              'boris',
              20,
              status: SubstitutionParticipantStatus.removed,
            ),
            participant('viktor', 30),
          ],
          userIds: const ['stepan', 'boris'],
        );

        expect(result.participants.map((item) => item.userId), [
          'stepan',
          'andrey',
          'boris',
          'viktor',
        ]);

        expect(result.participants.map((item) => item.rotationOrder), [
          0,
          11,
          21,
          31,
        ]);

        expect(result.createdUserIds, {'stepan'});
        expect(result.restoredUserIds, {'boris'});
        expect(result.addedCount, 2);
      },
    );

    test('existing participant cannot gain new-entry priority', () {
      final result = SubstitutionRotation.addOrRestoreParticipants(
        participants: [
          participant('andrey', 10),
          participant('stepan', 20),
          participant('viktor', 30),
        ],
        userIds: const ['stepan'],
      );

      expect(result.participants.map((item) => item.userId), [
        'andrey',
        'stepan',
        'viktor',
      ]);

      expect(result.participants.map((item) => item.rotationOrder), [
        10,
        20,
        30,
      ]);

      expect(result.addedCount, 0);
      expect(result.createdUserIds, isEmpty);
      expect(result.restoredUserIds, isEmpty);
    });

    test('several truly new participants keep requested order at front', () {
      final result = SubstitutionRotation.addOrRestoreParticipants(
        participants: [participant('andrey', 10), participant('viktor', 20)],
        userIds: const ['stepan', 'mikhail'],
      );

      expect(result.participants.map((item) => item.userId), [
        'stepan',
        'mikhail',
        'andrey',
        'viktor',
      ]);

      expect(result.participants.map((item) => item.rotationOrder), [
        0,
        1,
        12,
        22,
      ]);

      expect(result.addedCount, 2);
    });

    test('unknown participant cannot be called', () {
      expect(
        () => SubstitutionRotation.moveCalledParticipantToEnd(
          participants: [participant('ivanov', 10), participant('petrov', 20)],
          userId: 'sidorov',
        ),
        throwsArgumentError,
      );
    });
  });
}
