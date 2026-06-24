import 'package:flutter/material.dart';

class AddMembersCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddMembersCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_add),
        title: const Text('Добавить участника'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
