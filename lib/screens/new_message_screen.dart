import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'user_search_screen.dart';
import 'create_group_screen.dart';

class NewMessageScreen extends StatelessWidget {
  const NewMessageScreen({super.key});

  void openUserSearch(BuildContext context) {
    HapticFeedback.lightImpact();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новое сообщение')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_search)),
              title: const Text('Найти пользователя'),
              subtitle: const Text('По email или телефону'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openUserSearch(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.group_add)),
              title: const Text('Создать группу'),
              subtitle: const Text('Добавить нескольких участников'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                HapticFeedback.lightImpact();

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.hub)),
              title: const Text('Создать пространство'),
              subtitle: const Text('Для команд и отделов'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                HapticFeedback.selectionClick();
                debugPrint('Создать пространство');
              },
            ),
          ),
        ],
      ),
    );
  }
}
