import 'package:flutter/material.dart';

import 'substitution_queue_badge.dart';

class SubstitutionSettingsSheet extends StatefulWidget {
  const SubstitutionSettingsSheet({
    super.key,
    required this.queueDisplayMode,
    required this.showStatistics,
    required this.onQueueDisplayModeChanged,
    required this.onShowStatisticsChanged,
    this.onAddParticipants,
  });

  final SubstitutionQueueDisplayMode queueDisplayMode;
  final bool showStatistics;

  final ValueChanged<SubstitutionQueueDisplayMode> onQueueDisplayModeChanged;
  final ValueChanged<bool> onShowStatisticsChanged;

  /// Передаётся только для owner / brigadier.
  final VoidCallback? onAddParticipants;

  @override
  State<SubstitutionSettingsSheet> createState() =>
      _SubstitutionSettingsSheetState();
}

class _SubstitutionSettingsSheetState extends State<SubstitutionSettingsSheet> {
  late SubstitutionQueueDisplayMode _queueDisplayMode;
  late bool _showStatistics;

  @override
  void initState() {
    super.initState();

    _queueDisplayMode = widget.queueDisplayMode;
    _showStatistics = widget.showStatistics;
  }

  void _setQueueDisplayMode(SubstitutionQueueDisplayMode mode) {
    if (_queueDisplayMode == mode) {
      return;
    }

    setState(() {
      _queueDisplayMode = mode;
    });

    widget.onQueueDisplayModeChanged(mode);
  }

  void _setShowStatistics(bool value) {
    if (_showStatistics == value) {
      return;
    }

    setState(() {
      _showStatistics = value;
    });

    widget.onShowStatisticsChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final onAddParticipants = widget.onAddParticipants;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Настройки списка',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 22),

            Text(
              'Отображение очереди',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            SegmentedButton<SubstitutionQueueDisplayMode>(
              segments: const [
                ButtonSegment<SubstitutionQueueDisplayMode>(
                  value: SubstitutionQueueDisplayMode.avatarWithNumber,
                  icon: Icon(Icons.account_circle_outlined),
                  label: Text('Аватар'),
                ),
                ButtonSegment<SubstitutionQueueDisplayMode>(
                  value: SubstitutionQueueDisplayMode.numberOnly,
                  icon: Icon(Icons.format_list_numbered),
                  label: Text('Номер'),
                ),
              ],
              selected: {_queueDisplayMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }

                _setQueueDisplayMode(selection.first);
              },
            ),

            const SizedBox(height: 18),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _showStatistics,
              onChanged: _setShowStatistics,
              title: const Text('Показывать статистику'),
              subtitle: const Text('Статистика за месяц / год'),
              secondary: const Icon(Icons.bar_chart_outlined),
            ),

            if (onAddParticipants != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              Text(
                'Управление',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Добавить участников'),
                subtitle: const Text('Добавить людей в Список'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onAddParticipants,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
