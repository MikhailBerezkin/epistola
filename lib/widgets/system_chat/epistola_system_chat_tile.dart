import 'package:flutter/material.dart';

class EpistolaSystemChatTile extends StatelessWidget {
  static const String avatarAsset = 'assets/images/epistola_app_icon.png';

  final VoidCallback onTap;

  const EpistolaSystemChatTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('epistola-system-chat-tile'),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          key: Key('epistola-system-chat-avatar'),
          radius: 20,
          backgroundImage: AssetImage(avatarAsset),
        ),
        title: const Text(
          'Epistola',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const Text(
          'Технические сообщения',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
