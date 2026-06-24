import 'package:flutter/material.dart';

class MuteDurationSheet extends StatelessWidget {
  final ValueChanged<Duration> onDurationSelected;

  const MuteDurationSheet({super.key, required this.onDurationSelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Выдать мьют',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Причина: Флуд'),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('2 минуты'),
            onTap: () => onDurationSelected(const Duration(minutes: 2)),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('30 минут'),
            onTap: () => onDurationSelected(const Duration(minutes: 30)),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('1 час'),
            onTap: () => onDurationSelected(const Duration(hours: 1)),
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
        ],
      ),
    );
  }
}
