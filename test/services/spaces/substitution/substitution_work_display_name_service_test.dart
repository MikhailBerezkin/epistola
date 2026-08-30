import 'package:epistola/services/spaces/substitution/substitution_work_display_name_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes normalized work display name', () async {
    String? writtenUserId;
    String? writtenWorkDisplayName;

    final service = SubstitutionWorkDisplayNameService(
      workDisplayNameWriter:
          ({required String userId, required String workDisplayName}) async {
            writtenUserId = userId;
            writtenWorkDisplayName = workDisplayName;
          },
    );

    await service.updateWorkDisplayName(
      userId: ' user-1 ',
      workDisplayName: '  Михаил  ',
    );

    expect(writtenUserId, 'user-1');
    expect(writtenWorkDisplayName, 'Михаил');
  });

  test('allows empty work display name to restore default name', () async {
    String? writtenWorkDisplayName;

    final service = SubstitutionWorkDisplayNameService(
      workDisplayNameWriter:
          ({required String userId, required String workDisplayName}) async {
            writtenWorkDisplayName = workDisplayName;
          },
    );

    await service.updateWorkDisplayName(
      userId: 'user-1',
      workDisplayName: '   ',
    );

    expect(writtenWorkDisplayName, '');
  });

  test('allows work display name with exactly 80 characters', () async {
    String? writtenWorkDisplayName;

    final service = SubstitutionWorkDisplayNameService(
      workDisplayNameWriter:
          ({required String userId, required String workDisplayName}) async {
            writtenWorkDisplayName = workDisplayName;
          },
    );

    final name = List<String>.filled(80, 'А').join();

    await service.updateWorkDisplayName(
      userId: 'user-1',
      workDisplayName: name,
    );

    expect(writtenWorkDisplayName, name);
  });

  test('rejects work display name longer than 80 characters', () {
    final service = _service();
    final name = List<String>.filled(81, 'А').join();

    expect(
      () => service.updateWorkDisplayName(
        userId: 'user-1',
        workDisplayName: name,
      ),
      throwsArgumentError,
    );
  });

  test('rejects empty user id', () {
    final service = _service();

    expect(
      () => service.updateWorkDisplayName(
        userId: '   ',
        workDisplayName: 'Михаил',
      ),
      throwsArgumentError,
    );
  });

  test('rejects user id containing slash', () {
    final service = _service();

    expect(
      () => service.updateWorkDisplayName(
        userId: 'user/1',
        workDisplayName: 'Михаил',
      ),
      throwsArgumentError,
    );
  });
}

SubstitutionWorkDisplayNameService _service() {
  return SubstitutionWorkDisplayNameService(
    workDisplayNameWriter:
        ({required String userId, required String workDisplayName}) async {},
  );
}
