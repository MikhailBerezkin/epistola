import 'package:flutter/material.dart';

class GroupHeader extends StatelessWidget {
  final String groupName;
  final int memberCount;

  const GroupHeader({
    super.key,
    required this.groupName,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    final initial = groupName.isNotEmpty ? groupName[0].toUpperCase() : '?';

    return Column(
      children: [
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 48,
          child: Text(
            initial,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          groupName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '$memberCount участников',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
