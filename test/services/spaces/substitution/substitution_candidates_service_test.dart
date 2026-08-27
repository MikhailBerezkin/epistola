import 'package:epistola/models/app_user.dart';
import 'package:epistola/services/spaces/substitution/substitution_candidates_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppUser user({
    required String uid,
    required String name,
    String workDisplayName = '',
    String email = '',
  }) {
    return AppUser(
      uid: uid,
      email: email,
      name: name,
      workDisplayName: workDisplayName,
      phone: '',
      about: '',
    );
  }

  test('excludes users already present in substitution', () async {
    final service = SubstitutionCandidatesService(
      candidatesLoader: () async => [
        user(uid: 'user-1', name: 'Alex'),
        user(uid: 'user-2', name: 'Boris'),
        user(uid: 'user-3', name: 'Chris'),
      ],
    );

    final result = await service.loadCandidates(excludedUserIds: ['user-2']);

    expect(result.map((candidate) => candidate.uid), ['user-1', 'user-3']);
  });

  test('normalizes excluded user ids', () async {
    final service = SubstitutionCandidatesService(
      candidatesLoader: () async => [
        user(uid: 'user-1', name: 'Alex'),
        user(uid: 'user-2', name: 'Boris'),
      ],
    );

    final result = await service.loadCandidates(
      excludedUserIds: [' user-1 ', '', '   '],
    );

    expect(result.map((candidate) => candidate.uid), ['user-2']);
  });

  test('sorts by effective work display name', () async {
    final service = SubstitutionCandidatesService(
      candidatesLoader: () async => [
        user(uid: 'user-3', name: 'Charlie', workDisplayName: 'Яков Петров'),
        user(uid: 'user-1', name: 'Alex', workDisplayName: 'Александр Иванов'),
        user(uid: 'user-2', name: 'Boris', workDisplayName: 'Борис Сидоров'),
      ],
    );

    final result = await service.loadCandidates();

    expect(result.map((candidate) => candidate.uid), [
      'user-1',
      'user-2',
      'user-3',
    ]);
  });

  test('falls back to name when work display name is empty', () async {
    final service = SubstitutionCandidatesService(
      candidatesLoader: () async => [
        user(uid: 'user-2', name: 'Boris'),
        user(uid: 'user-1', name: 'Alex'),
      ],
    );

    final result = await service.loadCandidates();

    expect(result.map((candidate) => candidate.uid), ['user-1', 'user-2']);
  });

  test('falls back to email and uid for unnamed users', () async {
    final service = SubstitutionCandidatesService(
      candidatesLoader: () async => [
        user(uid: 'user-z', name: '', email: 'z@example.com'),
        user(uid: 'user-a', name: '', email: 'a@example.com'),
        user(uid: 'user-b', name: ''),
      ],
    );

    final result = await service.loadCandidates();

    expect(result.map((candidate) => candidate.uid), [
      'user-a',
      'user-b',
      'user-z',
    ]);
  });
}
