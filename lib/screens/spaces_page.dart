import 'package:flutter/material.dart';

import 'substitution_space_screen.dart';

class SpacesPage extends StatelessWidget {
  const SpacesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пространства'),
        actions: [
          IconButton(
            tooltip: 'Настроить пространства',
            onPressed: () {
              _showSpacesSettingsPlaceholder(context);
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: [
          _SpaceTile(
            title: '"Подсменка"',
            subtitle: '"Список"',
            icon: Icons.groups_2_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SubstitutionSpaceScreen(),
                ),
              );
            },
          ),
          _SpaceTile(
            title: 'Судозаходы',
            subtitle: 'Суда и объём работ',
            icon: Icons.directions_boat_outlined,
            onTap: () {
              _showUnderDevelopment(context, 'Судозаходы');
            },
          ),
          _SpaceTile(
            title: 'Календарь смен',
            subtitle: 'Смены и рабочие события',
            icon: Icons.calendar_month_outlined,
            onTap: () {
              _showUnderDevelopment(context, 'Календарь смен');
            },
          ),
          _SpaceTile(
            title: 'Автобусы',
            subtitle: 'Расписание транспорта',
            icon: Icons.directions_bus_outlined,
            onTap: () {
              _showUnderDevelopment(context, 'Автобусы');
            },
          ),
          _SpaceTile(
            title: 'ОТ и ТБ',
            subtitle: 'Инструкции и поиск',
            icon: Icons.health_and_safety_outlined,
            onTap: () {
              _showUnderDevelopment(context, 'ОТ и ТБ');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showUnderDevelopment(BuildContext context, String title) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: const Text('Раздел пока в разработке.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('ОК'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSpacesSettingsPlaceholder(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Настройка пространств',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Выбор отображаемых плиток добавим следующим этапом.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: colorScheme.primary),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
