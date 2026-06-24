import 'package:flutter/material.dart';

class ModerationActionsSection extends StatelessWidget {
  final bool canModerate;
  final bool canBan;

  final bool isTargetGuest;
  final bool isMutedActive;
  final bool isBannedActive;

  final VoidCallback onMute;
  final VoidCallback onUnmute;
  final VoidCallback onBan;
  final VoidCallback onUnban;

  const ModerationActionsSection({
    super.key,
    required this.canModerate,
    required this.canBan,
    required this.isTargetGuest,
    required this.isMutedActive,
    required this.isBannedActive,
    required this.onMute,
    required this.onUnmute,
    required this.onBan,
    required this.onUnban,
  });

  @override
  Widget build(BuildContext context) {
    if (!canModerate) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        const Text(
          'Модерация',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        if (!isTargetGuest && !isMutedActive && !isBannedActive)
          Card(
            child: ListTile(
              leading: const Icon(Icons.volume_off),
              title: const Text('Выдать мьют'),
              subtitle: const Text('Пользователь сможет читать, но не писать'),
              onTap: onMute,
            ),
          ),

        if (isMutedActive)
          Card(
            child: ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Снять мьют'),
              onTap: onUnmute,
            ),
          ),

        if (canBan && !isBannedActive)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.block,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Забанить',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: onBan,
            ),
          ),

        if (canBan && isBannedActive)
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_open),
              title: const Text('Разбанить'),
              onTap: onUnban,
            ),
          ),
      ],
    );
  }
}
