import 'package:flutter/foundation.dart';

import 'avatar_replacement_controller.dart';

typedef AvatarLostDataRecoveryInvoker =
    Future<AvatarReplacementResult> Function({required String uid});

typedef AndroidPlatformCheck = bool Function();

final class AvatarLostDataRecoveryCoordinator {
  AvatarLostDataRecoveryCoordinator({
    AndroidPlatformCheck? isAndroid,
    bool isWeb = kIsWeb,
    TargetPlatform? targetPlatform,
  }) : _isAndroid =
           isAndroid ??
           (() =>
               !isWeb &&
               (targetPlatform ?? defaultTargetPlatform) ==
                   TargetPlatform.android);

  final AndroidPlatformCheck _isAndroid;

  bool _hasAttemptedRecovery = false;

  bool get hasAttemptedRecovery => _hasAttemptedRecovery;

  Future<AvatarReplacementResult?> recoverOnce({
    required String uid,
    required AvatarLostDataRecoveryInvoker recover,
  }) async {
    final normalizedUid = uid.trim();

    if (!_isAndroid() || normalizedUid.isEmpty || _hasAttemptedRecovery) {
      return null;
    }

    // Mark the attempt before awaiting so concurrent lifecycle notifications
    // cannot invoke image_picker more than once during this app launch.
    _hasAttemptedRecovery = true;
    return recover(uid: normalizedUid);
  }
}
