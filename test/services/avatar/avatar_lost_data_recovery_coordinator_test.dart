import 'dart:async';

import 'package:epistola/services/avatar/avatar_lost_data_recovery_coordinator.dart';
import 'package:epistola/services/avatar/avatar_replacement_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android recovery with no lost data runs once', () async {
    var recoveryCalls = 0;
    final coordinator = AvatarLostDataRecoveryCoordinator(
      isAndroid: () => true,
    );

    Future<AvatarReplacementResult> recover({required String uid}) async {
      recoveryCalls++;
      expect(uid, 'user-1');
      return const AvatarReplacementResult.cancelled();
    }

    final first = await coordinator.recoverOnce(
      uid: ' user-1 ',
      recover: recover,
    );
    final second = await coordinator.recoverOnce(
      uid: 'user-1',
      recover: recover,
    );

    expect(first?.status, AvatarReplacementStatus.cancelled);
    expect(second, isNull);
    expect(recoveryCalls, 1);
    expect(coordinator.hasAttemptedRecovery, isTrue);
  });

  test('concurrent lifecycle notifications invoke recovery once', () async {
    final recoveryResult = Completer<AvatarReplacementResult>();
    var recoveryCalls = 0;
    final coordinator = AvatarLostDataRecoveryCoordinator(
      isAndroid: () => true,
    );

    Future<AvatarReplacementResult> recover({required String uid}) {
      recoveryCalls++;
      return recoveryResult.future;
    }

    final first = coordinator.recoverOnce(uid: 'user-1', recover: recover);
    final second = await coordinator.recoverOnce(
      uid: 'user-1',
      recover: recover,
    );

    expect(second, isNull);
    expect(recoveryCalls, 1);

    recoveryResult.complete(const AvatarReplacementResult.cancelled());
    expect((await first)?.status, AvatarReplacementStatus.cancelled);
  });

  test('non-Android platforms never invoke recovery', () async {
    var recoveryCalls = 0;
    final coordinator = AvatarLostDataRecoveryCoordinator(
      isAndroid: () => false,
    );

    final result = await coordinator.recoverOnce(
      uid: 'user-1',
      recover: ({required uid}) async {
        recoveryCalls++;
        return const AvatarReplacementResult.cancelled();
      },
    );

    expect(result, isNull);
    expect(recoveryCalls, 0);
    expect(coordinator.hasAttemptedRecovery, isFalse);
  });

  test('Flutter Web on an Android target never invokes recovery', () async {
    var recoveryCalls = 0;
    final coordinator = AvatarLostDataRecoveryCoordinator(
      isWeb: true,
      targetPlatform: TargetPlatform.android,
    );

    final result = await coordinator.recoverOnce(
      uid: 'user-1',
      recover: ({required uid}) async {
        recoveryCalls++;
        return const AvatarReplacementResult.cancelled();
      },
    );

    expect(result, isNull);
    expect(recoveryCalls, 0);
    expect(coordinator.hasAttemptedRecovery, isFalse);
  });

  test('waits for a non-empty authenticated user id', () async {
    var recoveryCalls = 0;
    final coordinator = AvatarLostDataRecoveryCoordinator(
      isAndroid: () => true,
    );

    Future<AvatarReplacementResult> recover({required String uid}) async {
      recoveryCalls++;
      return const AvatarReplacementResult.cancelled();
    }

    expect(await coordinator.recoverOnce(uid: '', recover: recover), isNull);
    expect(coordinator.hasAttemptedRecovery, isFalse);

    await coordinator.recoverOnce(uid: 'user-1', recover: recover);

    expect(recoveryCalls, 1);
    expect(coordinator.hasAttemptedRecovery, isTrue);
  });
}
