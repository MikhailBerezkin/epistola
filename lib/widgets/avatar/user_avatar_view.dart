import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import 'avatar_view.dart';

enum UserAvatarImageVariant { thumbnail, full }

class UserAvatarView extends StatelessWidget {
  final AppUser user;
  final double radius;
  final UserAvatarImageVariant imageVariant;

  const UserAvatarView({
    super.key,
    required this.user,
    required this.radius,
    this.imageVariant = UserAvatarImageVariant.thumbnail,
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

    return AvatarView(
      stableKey: _stableKey,
      name: user.name,
      email: user.email,
      radius: radius,
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
