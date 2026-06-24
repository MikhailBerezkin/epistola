import 'package:flutter/material.dart';

class BanDurationSheet extends StatelessWidget {
  final ValueChanged<Duration?> onDurationSelected;

  const BanDurationSheet({super.key, required this.onDurationSelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Забанить участника',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Причина: Нарушение правил'),
          ),
          ListTile(
            leading: const Icon(Icons.today),
            title: const Text('1 день'),
            onTap: () => onDurationSelected(const Duration(days: 1)),
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('7 дней'),
            onTap: () => onDurationSelected(const Duration(days: 7)),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('30 дней'),
            onTap: () => onDurationSelected(const Duration(days: 30)),
          ),
          ListTile(
            leading: const Icon(Icons.all_inclusive),
            title: const Text('Навсегда'),
            onTap: () => onDurationSelected(null),
          ),
        ],
      ),
    );
  }
}
