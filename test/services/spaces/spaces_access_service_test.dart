import 'dart:async';

import 'package:epistola/domain/models/spaces_access_role.dart';
import 'package:epistola/services/spaces/spaces_access_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns owner role', () async {
    final service = SpacesAccessService(
      roleReader: ({required String userId}) async {
        return SpacesAccessRole.owner;
      },
    );

    expect(await service.getRole(userId: 'user-1'), SpacesAccessRole.owner);
  });

  test('returns brigadier role', () async {
    final service = SpacesAccessService(
      roleReader: ({required String userId}) async {
        return SpacesAccessRole.brigadier;
      },
    );

    expect(await service.getRole(userId: 'user-1'), SpacesAccessRole.brigadier);
  });

  test('missing access document falls back to member', () async {
    final service = SpacesAccessService(
      roleReader: ({required String userId}) async {
        return null;
      },
    );

    expect(await service.getRole(userId: 'user-1'), SpacesAccessRole.member);
  });

  test('normalizes user id before reading', () async {
    String? receivedUserId;

    final service = SpacesAccessService(
      roleReader: ({required String userId}) async {
        receivedUserId = userId;
        return null;
      },
    );

    await service.getRole(userId: ' user-1 ');

    expect(receivedUserId, 'user-1');
  });

  test('reuses cached role without another read', () async {
    var readCount = 0;

    final service = SpacesAccessService(
      roleReader: ({required String userId}) async {
        readCount++;
        return SpacesAccessRole.brigadier;
      },
    );

    final firstRole = await service.getRole(userId: 'user-1');

    final secondRole = await service.getRole(userId: 'user-1');

    expect(firstRole, SpacesAccessRole.brigadier);
    expect(secondRole, SpacesAccessRole.brigadier);
    expect(readCount, 1);
  });

  test('concurrent requests share one role read', () async {
    var readCount = 0;
    final completer = Completer<SpacesAccessRole?>();

    final service = SpacesAccessService(
      roleReader: ({required String userId}) {
        readCount++;
        return completer.future;
      },
    );

    final firstFuture = service.getRole(userId: 'user-1');

    final secondFuture = service.getRole(userId: 'user-1');

    expect(readCount, 1);

    completer.complete(SpacesAccessRole.owner);

    expect(await firstFuture, SpacesAccessRole.owner);

    expect(await secondFuture, SpacesAccessRole.owner);

    expect(readCount, 1);
  });

  test('invalidating role forces the next read', () async {
    var readCount = 0;

    final service = SpacesAccessService(
      roleReader: ({required String userId}) async {
        readCount++;

        return readCount == 1
            ? SpacesAccessRole.brigadier
            : SpacesAccessRole.member;
      },
    );

    expect(await service.getRole(userId: 'user-1'), SpacesAccessRole.brigadier);

    service.invalidateRole(userId: 'user-1');

    expect(await service.getRole(userId: 'user-1'), SpacesAccessRole.member);

    expect(readCount, 2);
  });

  test('rejects empty user id', () {
    final service = _service();

    expect(() => service.getRole(userId: '   '), throwsArgumentError);
  });

  test('rejects user id containing slash', () {
    final service = _service();

    expect(() => service.getRole(userId: 'user/1'), throwsArgumentError);
  });
}

SpacesAccessService _service() {
  return SpacesAccessService(
    roleReader: ({required String userId}) async => null,
  );
}
