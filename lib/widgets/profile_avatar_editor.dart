import 'package:flutter/material.dart';

import '../domain/models/user_avatar.dart';
import '../models/app_user.dart';
import '../services/avatar/avatar_image_compressor_gateway.dart';
import '../services/avatar/avatar_image_crop_gateway.dart';
import '../services/avatar/avatar_image_loader.dart';
import '../services/avatar/avatar_image_processor.dart';
import '../services/avatar/avatar_replacement_controller.dart';
import 'profile_header.dart';

class ProfileAvatarEditor extends StatefulWidget {
  const ProfileAvatarEditor({
    super.key,
    required this.user,
    required this.name,
    required this.email,
    required this.onNameTap,
    required this.controller,
    this.avatarImageLoader,
  });

  final AppUser user;
  final String name;
  final String email;
  final VoidCallback onNameTap;
  final AvatarReplacementController controller;
  final AvatarImageLoader? avatarImageLoader;

  @override
  State<ProfileAvatarEditor> createState() => _ProfileAvatarEditorState();
}

class _ProfileAvatarEditorState extends State<ProfileAvatarEditor> {
  UserAvatar? _localAvatar;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ProfileAvatarEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }

    final localAvatar = _localAvatar;
    final streamedAvatar = widget.user.effectiveAvatar;

    if (localAvatar != null &&
        streamedAvatar != null &&
        streamedAvatar.version >= localAvatar.version) {
      _localAvatar = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showAvatarActions() async {
    if (widget.controller.isLoading) {
      return;
    }

    final source = await showModalBottomSheet<AvatarReplacementSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _AvatarSourceSheet(),
    );

    if (source == null || !mounted) {
      return;
    }

    final result = await widget.controller.replace(
      uid: widget.user.uid,
      source: source,
    );

    if (!mounted) {
      return;
    }

    switch (result.status) {
      case AvatarReplacementStatus.success:
        setState(() => _localAvatar = result.avatar);
      case AvatarReplacementStatus.failure:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_errorMessage(result, source))),
          );
      case AvatarReplacementStatus.cancelled:
      case AvatarReplacementStatus.alreadyRunning:
        break;
    }
  }

  String _errorMessage(
    AvatarReplacementResult result,
    AvatarReplacementSource source,
  ) {
    final error = result.error;

    if (error is AvatarImageCropException) {
      return 'Не удалось обрезать фото. Старый аватар сохранён.';
    }

    if (error is AvatarImageCompressorException ||
        error is AvatarImageProcessorException ||
        error is AvatarImageHardLimitExceededException) {
      return 'Не удалось обработать фото. Старый аватар сохранён.';
    }

    if (result.failureStage == AvatarReplacementFailureStage.preparation) {
      return switch (source) {
        AvatarReplacementSource.gallery =>
          'Не удалось выбрать фото из галереи. Попробуйте ещё раз.',
        AvatarReplacementSource.camera =>
          'Не удалось сделать фото. Проверьте доступ к камере.',
      };
    }

    return 'Не удалось сохранить новый аватар. Старый аватар сохранён.';
  }

  @override
  Widget build(BuildContext context) {
    final localAvatar = _newestAvatar(
      _localAvatar,
      widget.controller.latestAvatar,
    );
    final avatarUser = localAvatar == null
        ? widget.user
        : AppUser(
            uid: widget.user.uid,
            email: widget.user.email,
            name: widget.user.name,
            phone: widget.user.phone,
            about: widget.user.about,
            avatarUrl: widget.user.avatarUrl,
            avatar: localAvatar,
            createdAt: widget.user.createdAt,
          );

    return ProfileHeader(
      avatarUser: avatarUser,
      name: widget.name,
      email: widget.email,
      onNameTap: widget.onNameTap,
      onAvatarTap: _showAvatarActions,
      isAvatarLoading: widget.controller.isLoading,
      avatarImageLoader: widget.avatarImageLoader,
    );
  }

  UserAvatar? _newestAvatar(UserAvatar? first, UserAvatar? second) {
    final streamedAvatar = widget.user.effectiveAvatar;
    var newest = streamedAvatar;

    for (final avatar in [first, second]) {
      if (avatar != null &&
          (newest == null || avatar.version > newest.version)) {
        newest = avatar;
      }
    }

    return identical(newest, streamedAvatar) ? null : newest;
  }
}

class _AvatarSourceSheet extends StatelessWidget {
  const _AvatarSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Выбрать из галереи'),
            onTap: () {
              Navigator.pop(context, AvatarReplacementSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Сделать фото'),
            onTap: () {
              Navigator.pop(context, AvatarReplacementSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Отмена'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
