import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/services/work_schedule/user_assigned_crew_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes normalized initial crew selection', () async {
    String? writtenUserId;
    int? writtenCrewNumber;

    final service = UserAssignedCrewService(
      assignedCrewWriter:
          ({required String userId, required int crewNumber}) async {
            writtenUserId = userId;
            writtenCrewNumber = crewNumber;
          },
    );

    await service.selectInitialCrew(userId: ' user-1 ', crew: ShiftCrew.crew4);

    expect(writtenUserId, 'user-1');
    expect(writtenCrewNumber, 4);
  });

  test('manager correction writes selected crew', () async {
    String? writtenUserId;
    int? writtenCrewNumber;

    final service = UserAssignedCrewService(
      assignedCrewWriter:
          ({required String userId, required int crewNumber}) async {
            writtenUserId = userId;
            writtenCrewNumber = crewNumber;
          },
    );

    await service.correctCrewAsManager(userId: 'user-2', crew: ShiftCrew.crew2);

    expect(writtenUserId, 'user-2');
    expect(writtenCrewNumber, 2);
  });

  test('writes every supported crew number', () async {
    final writtenCrewNumbers = <int>[];

    final service = UserAssignedCrewService(
      assignedCrewWriter:
          ({required String userId, required int crewNumber}) async {
            writtenCrewNumbers.add(crewNumber);
          },
    );

    for (final crew in ShiftCrew.values) {
      await service.selectInitialCrew(userId: 'user-1', crew: crew);
    }

    expect(writtenCrewNumbers, [1, 2, 3, 4]);
  });

  test('rejects empty user id for initial selection', () {
    final service = _service();

    expect(
      () => service.selectInitialCrew(userId: '   ', crew: ShiftCrew.crew1),
      throwsArgumentError,
    );
  });

  test('rejects user id containing slash for manager correction', () {
    final service = _service();

    expect(
      () =>
          service.correctCrewAsManager(userId: 'user/1', crew: ShiftCrew.crew3),
      throwsArgumentError,
    );
  });
}

UserAssignedCrewService _service() {
  return UserAssignedCrewService(
    assignedCrewWriter:
        ({required String userId, required int crewNumber}) async {},
  );
}
