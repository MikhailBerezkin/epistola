import 'package:flutter/material.dart';

class LeaveGroupCard extends StatelessWidget {
  final VoidCallback onTap;

  const LeaveGroupCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
        title: Text(
          'Покинуть группу',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        onTap: onTap,
      ),
    );
  }
}
