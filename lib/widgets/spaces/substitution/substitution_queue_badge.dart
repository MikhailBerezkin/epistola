import 'package:flutter/material.dart';

import '../../../domain/models/substitution_participant.dart';
import 'substitution_availability_style.dart';

enum SubstitutionQueueDisplayMode { avatarWithNumber, numberOnly }

class SubstitutionQueueBadge extends StatelessWidget {
  const SubstitutionQueueBadge({
    super.key,
    required this.avatar,
    required this.queuePosition,
    required this.availability,
    this.displayMode = SubstitutionQueueDisplayMode.avatarWithNumber,
  });

  final Widget avatar;
  final int? queuePosition;
  final SubstitutionAvailability availability;
  final SubstitutionQueueDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    final position = queuePosition;

    if (position == null) {
      return avatar;
    }

    return switch (displayMode) {
      SubstitutionQueueDisplayMode.avatarWithNumber => _buildAvatarWithNumber(
        context,
        position,
      ),
      SubstitutionQueueDisplayMode.numberOnly => _buildNumberOnly(
        context,
        position,
      ),
    };
  }

  Widget _buildAvatarWithNumber(BuildContext context, int position) {
    final colorScheme = Theme.of(context).colorScheme;
    final availabilityLabel = substitutionAvailabilityLabel(availability);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          left: -3,
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

  Widget _buildNumberOnly(BuildContext context, int position) {
    final colorScheme = Theme.of(context).colorScheme;
    final availabilityLabel = substitutionAvailabilityLabel(availability);

    return Tooltip(
      message: '$availabilityLabel · № $position в очереди',
      child: Semantics(
        label:
            'Место в очереди: $position. '
            'Доступность: $availabilityLabel',
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface,
            border: Border.all(
              color: substitutionAvailabilityColor(availability),
              width: 2,
            ),
          ),
          child: Text(
            '$position',
            maxLines: 1,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
