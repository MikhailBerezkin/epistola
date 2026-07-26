import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/avatar/avatar_image_loader.dart';
import 'avatar/user_avatar_view.dart';

class ProfileHeader extends StatelessWidget {
  final AppUser avatarUser;
  final String name;
  final String email;
  final VoidCallback onNameTap;
  final VoidCallback? onAvatarTap;
  final bool isAvatarLoading;
  final AvatarImageLoader? avatarImageLoader;

  const ProfileHeader({
    super.key,
    required this.avatarUser,
    required this.name,
    required this.email,
    required this.onNameTap,
    this.onAvatarTap,
    this.isAvatarLoading = false,
    this.avatarImageLoader,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Semantics(
          button: onAvatarTap != null,
          label: 'Изменить аватар',
          child: Stack(
            alignment: Alignment.center,
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: isAvatarLoading ? null : onAvatarTap,
                  child: UserAvatarView(
                    user: avatarUser,
                    radius: 48,
                    imageVariant: UserAvatarImageVariant.full,
                    imageLoader: avatarImageLoader,
                  ),
                ),
              ),
              if (isAvatarLoading) ...[
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox.square(
                  dimension: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onNameTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 20),
              ],
            ),
          ),
        ),
        if (email.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            email,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ],
    );
  }
}
