import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/avatar/avatar_image_loader.dart';
import '../../services/avatar/avatar_image_pipeline_config.dart';
import 'avatar_view.dart';

enum UserAvatarImageVariant { thumbnail, full }

class UserAvatarView extends StatelessWidget {
  final AppUser user;
  final double radius;
  final UserAvatarImageVariant imageVariant;
  final AvatarImageLoader? imageLoader;

  const UserAvatarView({
    super.key,
    required this.user,
    required this.radius,
    this.imageVariant = UserAvatarImageVariant.thumbnail,
    this.imageLoader,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = user.effectiveAvatar;

    final imageUrl = switch (imageVariant) {
      UserAvatarImageVariant.thumbnail => user.effectiveAvatarThumbnailUrl,
      UserAvatarImageVariant.full => user.effectiveAvatarFullUrl,
    };

    final cacheKey = switch (imageVariant) {
      UserAvatarImageVariant.thumbnail => avatar?.thumbnailCacheKey(user.uid),
      UserAvatarImageVariant.full => avatar?.fullCacheKey(user.uid),
    };
    final storagePath = switch (imageVariant) {
      UserAvatarImageVariant.thumbnail => avatar?.thumbnailStoragePath,
      UserAvatarImageVariant.full => avatar?.fullStoragePath,
    };
    final maximumBytes = switch (imageVariant) {
      UserAvatarImageVariant.thumbnail =>
        AvatarImagePipelineConfig.hardThumbnailSizeBytes,
      UserAvatarImageVariant.full =>
        AvatarImagePipelineConfig.hardFullSizeBytes,
    };

    return AvatarView(
      stableKey: _stableKey,
      name: user.name,
      email: user.email,
      radius: radius,
      storagePath: storagePath,
      version: avatar?.version,
      maximumBytes: avatar == null ? null : maximumBytes,
      imageLoader: imageLoader,
      imageUrl: imageUrl,
      cacheKey: cacheKey,
    );
  }

  String get _stableKey {
    final uid = user.uid.trim();

    if (uid.isNotEmpty) {
      return uid;
    }

    final email = user.email.trim();

    if (email.isNotEmpty) {
      return email;
    }

    final name = user.name.trim();

    return name.isEmpty ? '?' : name;
  }
}
