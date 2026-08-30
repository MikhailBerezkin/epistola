import 'package:flutter/material.dart';

import '../../../domain/models/substitution_participant.dart';
import 'substitution_availability_style.dart';

class SubstitutionQueueBadge extends StatelessWidget {
  const SubstitutionQueueBadge({
    super.key,
    required this.avatar,
    required this.queuePosition,
    required this.availability,
  });

  final Widget avatar;
  final int? queuePosition;
  final SubstitutionAvailability availability;

  @override
  Widget build(BuildContext context) {
    final position = queuePosition;

    if (position == null) {
      return avatar;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final availabilityLabel = substitutionAvailabilityLabel(availability);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -3,
          bottom: -3,
          child: Tooltip(
            message: '$availabilityLabel · № $position в очереди',
            child: Semantics(
              label:
                  'Место в очереди: $position. '
                  'Доступность: $availabilityLabel',
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: substitutionAvailabilityColor(availability),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
                child: Text(
                  '$position',
                  style: TextStyle(
                    color: substitutionAvailabilityTextColor(availability),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
