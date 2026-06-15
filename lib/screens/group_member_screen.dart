import 'package:flutter/material.dart';

import '../models/app_user.dart';

class GroupMemberScreen extends StatelessWidget {
  final AppUser user;

  const GroupMemberScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user.name.isNotEmpty ? user.name : 'Без имени';
    final phone = user.phone.isNotEmpty ? user.phone : 'Не указан';
    final about = user.about.isNotEmpty ? user.about : 'Пока пусто';

    return Scaffold(
      appBar: AppBar(title: const Text('Участник группы')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 48,
            child: Text(
              displayName[0].toUpperCase(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              user.email,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Телефон'),
              subtitle: Text(phone),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('О себе'),
              subtitle: Text(about),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Управление участником',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Роль'),
              subtitle: const Text('Пока: участник'),
            ),
          ),
        ],
      ),
    );
  }
}
