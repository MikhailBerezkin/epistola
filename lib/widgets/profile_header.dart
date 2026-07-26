import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'avatar/user_avatar_view.dart';

class ProfileHeader extends StatelessWidget {
  final AppUser avatarUser;
  final String name;
  final String email;
  final VoidCallback onNameTap;

  const ProfileHeader({
    super.key,
    required this.avatarUser,
    required this.name,
    required this.email,
    required this.onNameTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        UserAvatarView(
          user: avatarUser,
          radius: 48,
          imageVariant: UserAvatarImageVariant.full,
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
