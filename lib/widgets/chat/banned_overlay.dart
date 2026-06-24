import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BannedOverlay extends StatelessWidget {
  final String chatId;

  const BannedOverlay({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;

        if (data == null || currentUser == null) {
          return const SizedBox.shrink();
        }

        final chatType = data['type'] ?? 'private';
        final memberStatus =
            (data['memberStatus'] as Map<String, dynamic>?) ?? {};
        final isGroup = chatType == 'group';

        final statusData =
            (memberStatus[currentUser.uid] as Map<String, dynamic>?) ??
            {'status': 'normal'};

        final status = statusData['status'] ?? 'normal';

        final isBanned =
            isGroup && status == 'banned' && _isStatusActive(statusData);

        if (!isBanned) {
          return const SizedBox.shrink();
        }

        final statusDetails = _formatStatusDetails(statusData);

        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Вы заблокированы в этой группе',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (statusDetails.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(statusDetails, textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Назад'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

bool _isStatusActive(Map<String, dynamic> statusData) {
  final permanent = statusData['permanent'] == true;
  final expiresAt = statusData['expiresAt'];

  if (permanent) return true;

  if (expiresAt is Timestamp) {
    return expiresAt.toDate().isAfter(DateTime.now());
  }

  return false;
}

String _formatStatusDetails(Map<String, dynamic> statusData) {
  final reason = statusData['reason'];
  final expiresAt = statusData['expiresAt'];
  final permanent = statusData['permanent'] == true;

  final parts = <String>[];

  if (reason != null && reason.toString().isNotEmpty) {
    parts.add('Причина: $reason');
  }

  if (permanent) {
    parts.add('Срок: навсегда');
  } else if (expiresAt is Timestamp) {
    final dateTime = expiresAt.toDate();

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    parts.add('До: $day.$month.$year $hour:$minute');
  }

  return parts.join('\n');
}
