import 'package:flutter/material.dart';

class GroupSettingsCard extends StatelessWidget {
  final VoidCallback onTap;

  const GroupSettingsCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.settings),
        title: const Text('Настройки'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
