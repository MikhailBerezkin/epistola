import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/services/spaces/substitution/substitution_work_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes normalized work profile', () async {
    String? writtenUserId;
    String? writtenWorkDisplayName;
    int? writtenCrewNumber;

    final service = SubstitutionWorkProfileService(
      workProfileWriter:
          ({
            required String userId,
            required String workDisplayName,
            required int crewNumber,
          }) async {
            writtenUserId = userId;
            writtenWorkDisplayName = workDisplayName;
            writtenCrewNumber = crewNumber;
          },
    );

    await service.updateWorkProfile(
      userId: ' user-1 ',
      workDisplayName: '  Михаил  ',
      crew: ShiftCrew.crew4,
    );

    expect(writtenUserId, 'user-1');
    expect(writtenWorkDisplayName, 'Михаил');
    expect(writtenCrewNumber, 4);
  });

  test('allows empty work display name', () async {
    String? writtenWorkDisplayName;

    final service = SubstitutionWorkProfileService(
      workProfileWriter:
          ({
            required String userId,
            required String workDisplayName,
            required int crewNumber,
          }) async {
            writtenWorkDisplayName = workDisplayName;
          },
    );

    await service.updateWorkProfile(
      userId: 'user-1',
      workDisplayName: '   ',
      crew: ShiftCrew.crew2,
    );

    expect(writtenWorkDisplayName, '');
  });

  test('writes every supported crew number', () async {
    final crewNumbers = <int>[];

    final service = SubstitutionWorkProfileService(
      workProfileWriter:
          ({
            required String userId,
            required String workDisplayName,
            required int crewNumber,
          }) async {
            crewNumbers.add(crewNumber);
          },
    );

    for (final crew in ShiftCrew.values) {
      await service.updateWorkProfile(
        userId: 'user-1',
        workDisplayName: '',
        crew: crew,
      );
    }

    expect(crewNumbers, [1, 2, 3, 4]);
  });

  test('rejects work display name longer than 80 characters', () {
    final service = _service();
    final name = List<String>.filled(81, 'А').join();

    expect(
      () => service.updateWorkProfile(
        userId: 'user-1',
        workDisplayName: name,
        crew: ShiftCrew.crew1,
      ),
      throwsArgumentError,
    );
  });

  test('rejects invalid user id', () {
    final service = _service();

    expect(
      () => service.updateWorkProfile(
        userId: 'user/1',
        workDisplayName: 'Михаил',
        crew: ShiftCrew.crew3,
      ),
      throwsArgumentError,
    );
  });
}

SubstitutionWorkProfileService _service() {
  return SubstitutionWorkProfileService(
    workProfileWriter:
        ({
          required String userId,
          required String workDisplayName,
          required int crewNumber,
        }) async {},
  );
}
