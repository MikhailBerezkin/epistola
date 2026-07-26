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
      ({required uid, required images}) {
        return replacement.replace(uid: uid, images: images);
      },
    );
  }

  factory AvatarReplacementController.withInvokers({
    required AvatarImagePreparationInvoker prepare,
    required AtomicAvatarReplacementInvoker replace,
  }) {
    return AvatarReplacementController._(prepare, replace);
  }

  AvatarReplacementController._(this._prepare, this._replace);

  final AvatarImagePreparationInvoker _prepare;
  final AtomicAvatarReplacementInvoker _replace;

  bool _isLoading = false;
  bool _isDisposed = false;

  bool get isLoading => _isLoading;

  Future<AvatarReplacementResult> replace({
    required String uid,
    required AvatarReplacementSource source,
  }) async {
    if (_isLoading) {
      return const AvatarReplacementResult.alreadyRunning();
    }

    _setLoading(true);
    PreparedAvatarImages? images;

    try {
      try {
        images = await _prepare(source);
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

  void _setLoading(bool value) {
    _isLoading = value;

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
