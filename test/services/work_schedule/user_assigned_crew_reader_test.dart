import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/services/work_schedule/user_assigned_crew_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('watches assigned crew for normalized user id', () async {
    String? watchedUserId;

    final reader = UserAssignedCrewReader(
      assignedCrewWatcher: ({required String userId}) {
        watchedUserId = userId;

        return Stream<ShiftCrew?>.value(ShiftCrew.crew4);
      },
    );

    final crew = await reader.watch(userId: ' user-1 ').first;

    expect(watchedUserId, 'user-1');
    expect(crew, ShiftCrew.crew4);
  });

  test('supports missing assigned crew', () async {
    final reader = UserAssignedCrewReader(
      assignedCrewWatcher: ({required String userId}) {
        return Stream<ShiftCrew?>.value(null);
      },
    );

    final crew = await reader.watch(userId: 'user-1').first;

    expect(crew, isNull);
  });

  test('passes realtime crew changes through the stream', () async {
    final reader = UserAssignedCrewReader(
      assignedCrewWatcher: ({required String userId}) {
        return Stream<ShiftCrew?>.fromIterable([
          ShiftCrew.crew2,
          ShiftCrew.crew4,
        ]);
      },
    );

    final crews = await reader.watch(userId: 'user-1').toList();

    expect(crews, [ShiftCrew.crew2, ShiftCrew.crew4]);
  });

  test('rejects empty user id', () {
    final reader = _reader();

    expect(() => reader.watch(userId: '   '), throwsArgumentError);
  });

  test('rejects user id containing slash', () {
    final reader = _reader();

    expect(() => reader.watch(userId: 'user/1'), throwsArgumentError);
  });
}

UserAssignedCrewReader _reader() {
  return UserAssignedCrewReader(
    assignedCrewWatcher: ({required String userId}) {
      return const Stream<ShiftCrew?>.empty();
    },
  );
}
