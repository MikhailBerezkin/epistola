import 'package:flutter/material.dart';

import '../../../domain/models/substitution_participant.dart';
import '../../../models/app_user.dart';
import '../../identity/identity_background.dart';
import '../../identity/identity_overlay.dart';
import 'substitution_availability_selector.dart';
import '../../../domain/models/substitution_shift.dart';
import 'substitution_statistics_summary.dart';

class SubstitutionParticipantOverlay extends StatelessWidget {
  const SubstitutionParticipantOverlay({
    super.key,
    required this.isOpen,
    required this.participant,
    required this.user,
    required this.queuePosition,
    required this.onClose,
    this.monthlyCallCount,
    this.statisticsMonth,
    this.monthShifts = const <SubstitutionShiftKind>[],
    this.yearCallCount,
    this.onEditName,
    this.onAvailabilityChanged,
    this.onVacation,
    this.onSick,
    this.onReturnToList,
    this.onRemove,
  });

  final bool isOpen;
  final SubstitutionParticipant? participant;
  final AppUser? user;
  final int? queuePosition;
  final int? monthlyCallCount;
  final int? statisticsMonth;
  final List<SubstitutionShiftKind> monthShifts;
  final int? yearCallCount;
  final VoidCallback onClose;
  final VoidCallback? onEditName;
  final ValueChanged<SubstitutionAvailability>? onAvailabilityChanged;
  final VoidCallback? onVacation;
  final VoidCallback? onSick;
  final VoidCallback? onReturnToList;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final currentParticipant = participant;

    if (currentParticipant == null) {
      return const SizedBox.shrink();
    }

    final currentUser = user;
    final displayName = _resolveDisplayName(
      participant: currentParticipant,
      user: currentUser,
    );

    final email = currentUser?.email.trim() ?? '';
    final avatar = currentUser?.effectiveAvatar;

    return IdentityOverlay(
      isOpen: isOpen,
      onClose: onClose,
      child: IdentityBackground(
        stableKey: currentParticipant.userId,
        name: displayName,
        email: email,
        storagePath: avatar?.fullStoragePath,
        version: avatar?.version,
        imageUrl: currentUser?.effectiveAvatarFullUrl,
        cacheKey: avatar?.fullCacheKey(currentParticipant.userId),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Закрыть',
                    onPressed: onClose,
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                const Spacer(),
                _ParticipantHeader(
                  displayName: displayName,
                  onEditName: onEditName,
                ),
                const SizedBox(height: 4),
                _ParticipantStatusLine(
                  participant: currentParticipant,
                  queuePosition: queuePosition,
                ),
                if (monthlyCallCount != null &&
                    statisticsMonth != null &&
                    yearCallCount != null) ...[
                  const SizedBox(height: 14),
                  SubstitutionStatisticsSummary(
                    month: statisticsMonth!,
                    monthCallCount: monthlyCallCount!,
                    monthShifts: monthShifts,
                    yearCallCount: yearCallCount!,
                  ),
                ] else if (monthlyCallCount != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Вызовов за месяц: $monthlyCallCount',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (currentParticipant.isActive) ...[
                  if (onAvailabilityChanged != null) ...[
                    Text(
                      'Доступность',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SubstitutionAvailabilitySelector(
                      availability: currentParticipant.availability,
                      onChanged: onAvailabilityChanged,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (onVacation != null || onSick != null)
                    Row(
                      children: [
                        if (onVacation != null)
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: onVacation,
                              child: const Text('Отпуск'),
                            ),
                          ),
                        if (onVacation != null && onSick != null)
                          const SizedBox(width: 12),
                        if (onSick != null)
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: onSick,
                              child: const Text('Больничный'),
                            ),
                          ),
                      ],
                    ),
                ] else ...[
                  if (onReturnToList != null)
                    FilledButton.tonal(
                      onPressed: onReturnToList,
                      child: const Text('Вернуть в список'),
                    ),
                ],
                if (onRemove != null) ...[
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.person_remove_outlined),
                    label: const Text('Удалить из списка'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveDisplayName({
    required SubstitutionParticipant participant,
    required AppUser? user,
  }) {
    if (user == null) {
      return participant.userId;
    }

    final workDisplayName = user.effectiveWorkDisplayName.trim();

    if (workDisplayName.isNotEmpty) {
      return workDisplayName;
    }

    final email = user.email.trim();

    if (email.isNotEmpty) {
      return email;
    }

    return participant.userId;
  }
}

class _ParticipantHeader extends StatelessWidget {
  const _ParticipantHeader({
    required this.displayName,
    required this.onEditName,
  });

  final String displayName;
  final VoidCallback? onEditName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (onEditName != null)
          IconButton(
            tooltip: 'Изменить рабочее имя',
            onPressed: onEditName,
            color: Colors.white,
            icon: const Icon(Icons.edit_outlined),
          ),
      ],
    );
  }
}

class _ParticipantStatusLine extends StatelessWidget {
  const _ParticipantStatusLine({
    required this.participant,
    required this.queuePosition,
  });

  final SubstitutionParticipant participant;
  final int? queuePosition;

  @override
  Widget build(BuildContext context) {
    final text = switch (participant.status) {
      SubstitutionParticipantStatus.active => _activeText(),
      SubstitutionParticipantStatus.vacation => 'Отпуск',
      SubstitutionParticipantStatus.sick => 'Больничный',
    };

    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Colors.white.withValues(alpha: 0.88),
      ),
    );
  }

  String _activeText() {
    final position = queuePosition;

    if (position == null) {
      return 'В активной очереди';
    }

    return '№ $position в очереди';
  }
}
