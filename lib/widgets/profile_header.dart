import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onNameTap;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.email,
    required this.onNameTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        CircleAvatar(
          radius: 48,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
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
        const SizedBox(height: 8),
        Text(
          email,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }
}
