import 'package:flutter/material.dart';

import '../domain/models/shift_cycle.dart';

class ShiftCalendarSettingsScreen extends StatefulWidget {
  const ShiftCalendarSettingsScreen({super.key, required this.initialCrew});

  final ShiftCrew initialCrew;

  @override
  State<ShiftCalendarSettingsScreen> createState() =>
      _ShiftCalendarSettingsScreenState();
}

class _ShiftCalendarSettingsScreenState
    extends State<ShiftCalendarSettingsScreen> {
  late ShiftCrew _selectedCrew;

  @override
  void initState() {
    super.initState();
    _selectedCrew = widget.initialCrew;
  }

  void _selectCrew(ShiftCrew crew) {
    if (_selectedCrew == crew) {
      return;
    }

    setState(() {
      _selectedCrew = crew;
    });

    Navigator.of(context).pop(crew);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки календаря')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Просмотр звена',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Можно временно посмотреть график другого звена. '
            'Ваше рабочее звено при этом не изменится.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (final crew in ShiftCrew.values) ...[
            Card(
              child: ListTile(
                title: Text(crew.displayName),
                trailing: crew == _selectedCrew
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : const Icon(Icons.circle_outlined),
                onTap: () => _selectCrew(crew),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
