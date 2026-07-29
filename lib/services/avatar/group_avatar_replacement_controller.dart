import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/group_avatar.dart';
import 'atomic_group_avatar_replacement_service.dart';
import 'avatar_image_preparation_service.dart';
import 'avatar_image_processor.dart';
import 'avatar_replacement_controller.dart' show AvatarReplacementSource;

enum GroupAvatarReplacementStatus {
  success,
  cancelled,
  failure,
  alreadyRunning,
}

enum GroupAvatarReplacementFailureStage { preparation, replacement }

typedef GroupAvatarImagePreparationInvoker =
    Future<PreparedAvatarImages?> Function(AvatarReplacementSource source);

typedef AtomicGroupAvatarReplacementInvoker =
    Future<GroupAvatar> Function({
      required String chatId,
      required PreparedAvatarImages images,
    });

final class GroupAvatarReplacementResult {
  const GroupAvatarReplacementResult._({
    required this.status,
    this.avatar,
    this.error,
    this.failureStage,
  });

  const GroupAvatarReplacementResult.success(GroupAvatar avatar)
    : this._(status: GroupAvatarReplacementStatus.success, avatar: avatar);

  const GroupAvatarReplacementResult.cancelled()
    : this._(status: GroupAvatarReplacementStatus.cancelled);

  const GroupAvatarReplacementResult.failure({
    required Object error,
    required GroupAvatarReplacementFailureStage stage,
  }) : this._(
         status: GroupAvatarReplacementStatus.failure,
         error: error,
         failureStage: stage,
       );

  const GroupAvatarReplacementResult.alreadyRunning()
    : this._(status: GroupAvatarReplacementStatus.alreadyRunning);

  final GroupAvatarReplacementStatus status;
  final GroupAvatar? avatar;
  final Object? error;
  final GroupAvatarReplacementFailureStage? failureStage;
}

final class GroupAvatarReplacementController extends ChangeNotifier {
  factory GroupAvatarReplacementController({
    required AvatarImagePreparationService preparation,
    required AtomicGroupAvatarReplacementService replacement,
  }) {
    return GroupAvatarReplacementController._(
      (source) => switch (source) {
        AvatarReplacementSource.gallery => preparation.prepareFromGallery(),
        AvatarReplacementSource.camera => preparation.prepareWithCamera(),
      },
      ({required chatId, required images}) {
        return replacement.replace(chatId: chatId, images: images);
      },
    );
  }

  factory GroupAvatarReplacementController.withInvokers({
    required GroupAvatarImagePreparationInvoker prepare,
    required AtomicGroupAvatarReplacementInvoker replace,
  }) {
    return GroupAvatarReplacementController._(prepare, replace);
  }

  GroupAvatarReplacementController._(this._prepare, this._replace);

  final GroupAvatarImagePreparationInvoker _prepare;
  final AtomicGroupAvatarReplacementInvoker _replace;

  bool _isLoading = false;
  bool _isDisposed = false;
  GroupAvatar? _latestAvatar;
  Completer<void>? _idleCompleter;

  bool get isLoading => _isLoading;

  GroupAvatar? get latestAvatar => _latestAvatar;

  Future<GroupAvatarReplacementResult> replace({
    required String chatId,
    required AvatarReplacementSource source,
  }) async {
    if (_isLoading) {
      return const GroupAvatarReplacementResult.alreadyRunning();
    }

    _setLoading(true);

    PreparedAvatarImages? images;

    try {
      try {
        images = await _prepare(source);
      } catch (error) {
        return GroupAvatarReplacementResult.failure(
          error: error,
          stage: GroupAvatarReplacementFailureStage.preparation,
        );
      }

      if (images == null) {
        return const GroupAvatarReplacementResult.cancelled();
      }

      try {
        final avatar = await _replace(chatId: chatId, images: images);

        _latestAvatar = avatar;

        return GroupAvatarReplacementResult.success(avatar);
      } catch (error) {
        return GroupAvatarReplacementResult.failure(
          error: error,
          stage: GroupAvatarReplacementFailureStage.replacement,
        );
      }
    } finally {
      try {
        await images?.cleanup();
      } catch (_) {
        // Локальный cleanup не должен менять результат удалённой операции.
      }

      _setLoading(false);
    }
  }

  Future<void> waitUntilIdle() async {
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
