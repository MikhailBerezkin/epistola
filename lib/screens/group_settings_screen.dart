import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'group_permissions_screen.dart';

class GroupSettingsScreen extends StatelessWidget {
  final String chatId;

  const GroupSettingsScreen({super.key, required this.chatId});

  void showComingSoon(BuildContext context) {
    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Добавим позже')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Настройки группы'),
              subtitle: const Text(
                'Права сообщений, файлов, фото и приглашений',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                HapticFeedback.selectionClick();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupPermissionsScreen(chatId: chatId),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Уведомления и звуки'),
              subtitle: const Text('Звук, вибрация и режим без звука'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showComingSoon(context),
            ),
          ),
        ],
      ),
    );
  }
}
