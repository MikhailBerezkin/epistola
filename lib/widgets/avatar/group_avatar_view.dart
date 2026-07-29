import 'package:flutter/material.dart';

import '../../domain/models/group_avatar.dart';
import '../../services/avatar/avatar_image_loader.dart';
import '../../services/avatar/avatar_image_pipeline_config.dart';
import 'avatar_view.dart';

enum GroupAvatarImageVariant { thumbnail, full }

class GroupAvatarView extends StatelessWidget {
  const GroupAvatarView({
    super.key,
    required this.chatId,
    required this.groupName,
    required this.radius,
    this.avatar,
    this.imageVariant = GroupAvatarImageVariant.thumbnail,
    this.imageLoader,
  });

  final String chatId;
  final String groupName;
  final double radius;
  final GroupAvatar? avatar;
  final GroupAvatarImageVariant imageVariant;
  final AvatarImageLoader? imageLoader;

  @override
  Widget build(BuildContext context) {
    final storagePath = switch (imageVariant) {
      GroupAvatarImageVariant.thumbnail => avatar?.thumbnailStoragePath,
      GroupAvatarImageVariant.full => avatar?.fullStoragePath,
    };

    final imageUrl = switch (imageVariant) {
      GroupAvatarImageVariant.thumbnail => avatar?.thumbnailUrl,
      GroupAvatarImageVariant.full => avatar?.fullUrl,
    };

    final cacheKey = switch (imageVariant) {
      GroupAvatarImageVariant.thumbnail => avatar?.thumbnailCacheKey(chatId),
      GroupAvatarImageVariant.full => avatar?.fullCacheKey(chatId),
    };

    final maximumBytes = switch (imageVariant) {
      GroupAvatarImageVariant.thumbnail =>
        AvatarImagePipelineConfig.hardThumbnailSizeBytes,
      GroupAvatarImageVariant.full =>
        AvatarImagePipelineConfig.hardFullSizeBytes,
    };

    return AvatarView(
      stableKey: _stableKey,
      name: _fallbackLetter,
      email: '',
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
    final normalizedChatId = chatId.trim();

    if (normalizedChatId.isNotEmpty) {
      return normalizedChatId;
    }

    final normalizedName = groupName.trim();

    return normalizedName.isEmpty ? '?' : normalizedName;
  }

  String get _fallbackLetter {
    final normalizedName = groupName.trim();

    if (normalizedName.isEmpty) {
      return '?';
    }

    return normalizedName[0].toUpperCase();
  }
}
