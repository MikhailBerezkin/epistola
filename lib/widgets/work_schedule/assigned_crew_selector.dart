import 'package:flutter/material.dart';

import '../../domain/models/shift_cycle.dart';

class AssignedCrewSelector extends StatelessWidget {
  const AssignedCrewSelector({
    super.key,
    required this.selectedCrew,
    required this.onChanged,
    this.enabled = true,
  });

  final ShiftCrew? selectedCrew;
  final ValueChanged<ShiftCrew> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selected = selectedCrew;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ваше звено', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Выберите номер звена, по которому рассчитывается ваш рабочий график.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<ShiftCrew>(
          segments: ShiftCrew.values
              .map(
                (crew) => ButtonSegment<ShiftCrew>(
                  value: crew,
                  label: Text('${crew.number}'),
                  tooltip: '${crew.number} звено',
                ),
              )
              .toList(growable: false),
          selected: selected == null ? const {} : <ShiftCrew>{selected},
          emptySelectionAllowed: true,
          onSelectionChanged: enabled
              ? (selection) {
                  if (selection.isEmpty) {
                    return;
                  }

                  onChanged(selection.first);
                }
              : null,
        ),
      ],
    );
  }
}
