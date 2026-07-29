import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/user_avatar.dart';
import 'atomic_avatar_replacement_service.dart';
import 'avatar_image_preparation_service.dart';
import 'avatar_image_processor.dart';

enum AvatarReplacementSource { gallery, camera }

enum AvatarReplacementStatus { success, cancelled, failure, alreadyRunning }

enum AvatarReplacementFailureStage { preparation, replacement }

typedef AvatarImagePreparationInvoker =
    Future<PreparedAvatarImages?> Function(AvatarReplacementSource source);

typedef RecoveredAvatarImagePreparationInvoker =
    Future<PreparedAvatarImages?> Function();

typedef AtomicAvatarReplacementInvoker =
    Future<UserAvatar> Function({
      required String uid,
      required PreparedAvatarImages images,
    });

final class AvatarReplacementResult {
  const AvatarReplacementResult._({
    required this.status,
    this.avatar,
    this.error,
    this.failureStage,
  });

  const AvatarReplacementResult.success(UserAvatar avatar)
    : this._(status: AvatarReplacementStatus.success, avatar: avatar);

  const AvatarReplacementResult.cancelled()
    : this._(status: AvatarReplacementStatus.cancelled);

  const AvatarReplacementResult.failure({
    required Object error,
    required AvatarReplacementFailureStage stage,
  }) : this._(
         status: AvatarReplacementStatus.failure,
         error: error,
         failureStage: stage,
       );

  const AvatarReplacementResult.alreadyRunning()
    : this._(status: AvatarReplacementStatus.alreadyRunning);

  final AvatarReplacementStatus status;
  final UserAvatar? avatar;
  final Object? error;
  final AvatarReplacementFailureStage? failureStage;
}

final class AvatarReplacementController extends ChangeNotifier {
  factory AvatarReplacementController({
    required AvatarImagePreparationService preparation,
    required AtomicAvatarReplacementService replacement,
  }) {
    return AvatarReplacementController._(
      (source) => switch (source) {
        AvatarReplacementSource.gallery => preparation.prepareFromGallery(),
        AvatarReplacementSource.camera => preparation.prepareWithCamera(),
      },
      preparation.prepareRecoveredLostImage,
      ({required uid, required images}) {
        return replacement.replace(uid: uid, images: images);
      },
    );
  }

  factory AvatarReplacementController.withInvokers({
    required AvatarImagePreparationInvoker prepare,
    RecoveredAvatarImagePreparationInvoker? prepareRecovered,
    required AtomicAvatarReplacementInvoker replace,
  }) {
    return AvatarReplacementController._(
      prepare,
      prepareRecovered ?? _noRecoveredImage,
      replace,
    );
  }

  AvatarReplacementController._(
    this._prepare,
    this._prepareRecovered,
    this._replace,
  );

  final AvatarImagePreparationInvoker _prepare;
  final RecoveredAvatarImagePreparationInvoker _prepareRecovered;
  final AtomicAvatarReplacementInvoker _replace;

  bool _isLoading = false;
  bool _isDisposed = false;
  UserAvatar? _latestAvatar;
  Completer<void>? _idleCompleter;

  bool get isLoading => _isLoading;
  UserAvatar? get latestAvatar => _latestAvatar;

  Future<AvatarReplacementResult> replace({
    required String uid,
    required AvatarReplacementSource source,
  }) async {
    return _run(uid: uid, prepare: () => _prepare(source));
  }

  Future<AvatarReplacementResult> recoverLostImage({required String uid}) {
    if (!_isLoading) {
      return _run(uid: uid, prepare: _prepareRecovered);
    }

    return _recoverWhenIdle(uid);
  }

  Future<AvatarReplacementResult> _recoverWhenIdle(String uid) async {
    await _waitUntilIdle();
    return _run(uid: uid, prepare: _prepareRecovered);
  }

  Future<AvatarReplacementResult> _run({
    required String uid,
    required Future<PreparedAvatarImages?> Function() prepare,
  }) async {
    if (_isLoading) {
      return const AvatarReplacementResult.alreadyRunning();
    }

    _setLoading(true);
    PreparedAvatarImages? images;

    try {
      try {
        images = await prepare();
      } catch (error) {
        return AvatarReplacementResult.failure(
          error: error,
          stage: AvatarReplacementFailureStage.preparation,
        );
      }

      if (images == null) {
        return const AvatarReplacementResult.cancelled();
      }

      try {
        final avatar = await _replace(uid: uid, images: images);
        _latestAvatar = avatar;
        return AvatarReplacementResult.success(avatar);
      } catch (error) {
        return AvatarReplacementResult.failure(
          error: error,
          stage: AvatarReplacementFailureStage.replacement,
        );
      }
    } finally {
      await images?.cleanup();
      _setLoading(false);
    }
  }

  static Future<PreparedAvatarImages?> _noRecoveredImage() async => null;

  Future<void> _waitUntilIdle() async {
    while (_isLoading) {
      await _idleCompleter?.future;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;

    if (value) {
      _idleCompleter = Completer<void>();
    } else {
      _idleCompleter?.complete();
      _idleCompleter = null;
    }

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
