import 'package:flutter/material.dart';

import '../../../domain/models/substitution_participant.dart';
import 'substitution_availability_style.dart';

class SubstitutionAvailabilitySelector extends StatelessWidget {
  const SubstitutionAvailabilitySelector({
    super.key,
    required this.availability,
    this.onChanged,
  });

  final SubstitutionAvailability availability;
  final ValueChanged<SubstitutionAvailability>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: SubstitutionAvailability.values
          .map(
            (value) => Expanded(
              child: _AvailabilityChoice(
                availability: value,
                selected: availability == value,
                onTap: onChanged == null
                    ? null
                    : () {
                        onChanged!(value);
                      },
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AvailabilityChoice extends StatelessWidget {
  const _AvailabilityChoice({
    required this.availability,
    required this.selected,
    required this.onTap,
  });

  final SubstitutionAvailability availability;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = substitutionAvailabilityLabel(availability);
    final color = substitutionAvailabilityColor(availability);
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      child: Semantics(
        button: onTap != null,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? colorScheme.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: selected
                        ? Icon(
                            Icons.check,
                            size: 20,
                            color: substitutionAvailabilityTextColor(
                              availability,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
