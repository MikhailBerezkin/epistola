import 'package:flutter/material.dart';

class DissolveGroupCard extends StatelessWidget {
  final VoidCallback onTap;

  const DissolveGroupCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.delete_forever, color: Colors.red),
        title: const Text(
          'Распустить группу',
          style: TextStyle(color: Colors.red),
        ),
        subtitle: const Text('Закрыть группу для всех участников'),
        onTap: onTap,
      ),
    );
  }
}
