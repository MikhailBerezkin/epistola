import 'package:flutter/material.dart';

import '../../../domain/models/substitution_participant.dart';
import '../../../models/app_user.dart';
import '../../avatar/user_avatar_view.dart';
import 'substitution_queue_badge.dart';
import 'substitution_statistics_badge.dart';

class SubstitutionParticipantRow extends StatelessWidget {
  const SubstitutionParticipantRow({
    super.key,
    required this.participant,
    required this.user,
    required this.queuePosition,
    required this.onOpenCard,
    this.queueDisplayMode = SubstitutionQueueDisplayMode.avatarWithNumber,
    this.secondaryText,
    this.statisticsCount,
    this.onCall,
  });

  final SubstitutionParticipant participant;
  final AppUser? user;
  final int? queuePosition;
  final SubstitutionQueueDisplayMode queueDisplayMode;
  final String? secondaryText;
  final VoidCallback? onCall;
  final int? statisticsCount;
  final VoidCallback onOpenCard;

  @override
  Widget build(BuildContext context) {
    final resolvedUser = user;
    final displayName = _resolveDisplayName();

    final avatar = resolvedUser == null
        ? const CircleAvatar(radius: 22, child: Icon(Icons.person_outline))
        : UserAvatarView(user: resolvedUser, radius: 22);

    return ListTile(
      leading: SubstitutionQueueBadge(
        avatar: avatar,
        queuePosition: queuePosition,
        availability: participant.availability,
        displayMode: queueDisplayMode,
      ),
      title: Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: _buildSubtitle(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onCall != null) ...[
            FilledButton.tonal(
              onPressed: onCall,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                textStyle: const TextStyle(fontSize: 13),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Вызвать'),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            tooltip: 'Открыть карточку',
            onPressed: onOpenCard,
            icon: const Icon(Icons.more_vert),
          ),
          if (statisticsCount != null) ...[
            const SizedBox(width: 2),
            SubstitutionStatisticsBadge(count: statisticsCount!),
          ],
        ],
      ),
    );
  }

  Widget? _buildSubtitle() {
    final normalizedSecondaryText = secondaryText?.trim();

    if (normalizedSecondaryText == null || normalizedSecondaryText.isEmpty) {
      return null;
    }

    return Text(
      normalizedSecondaryText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _resolveDisplayName() {
    final resolvedUser = user;

    if (resolvedUser == null) {
      return participant.userId;
    }

    final workDisplayName = resolvedUser.effectiveWorkDisplayName.trim();

    if (workDisplayName.isNotEmpty) {
      return workDisplayName;
    }

    final email = resolvedUser.email.trim();

    if (email.isNotEmpty) {
      return email;
    }

    return participant.userId;
  }
}
