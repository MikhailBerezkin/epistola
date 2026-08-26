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
