import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/app_user.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import '../helpers/role_helper.dart';
import '../helpers/status_helper.dart';
import '../widgets/group/mute_duration_sheet.dart';
import '../widgets/group/ban_duration_sheet.dart';
import '../widgets/group/member_status_card.dart';
import '../widgets/group/member_role_card.dart';
import '../widgets/group/role_selection_sheet.dart';
import '../widgets/group/moderation_actions_section.dart';

class GroupMemberScreen extends StatelessWidget {
  final String chatId;
  final AppUser user;

  const GroupMemberScreen({
    super.key,
    required this.chatId,
    required this.user,
  });

  Future<void> updateRole({required String role}) async {
    await ChatService().updateMemberRole(
      chatId: chatId,
      userId: user.uid,
      role: role,
    );
  }

  Future<void> showMuteSheet(BuildContext context) async {
    final service = ChatService();

    Future<void> muteFor(Duration duration) async {
      HapticFeedback.mediumImpact();

      final expiresAt = DateTime.now().add(duration);

      await service.muteMember(
        chatId: chatId,
        userId: user.uid,
        reason: 'Флуд',
        expiresAt: expiresAt,
      );

      if (context.mounted) Navigator.pop(context);
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return MuteDurationSheet(onDurationSelected: muteFor);
      },
    );
  }

  Future<void> showBanSheet(BuildContext context) async {
    final service = ChatService();

    Future<void> banFor(Duration? duration) async {
      HapticFeedback.mediumImpact();

      final expiresAt = duration == null ? null : DateTime.now().add(duration);

      await service.banMember(
        chatId: chatId,
        userId: user.uid,
        reason: 'Нарушение правил',
        expiresAt: expiresAt,
      );

      if (context.mounted) Navigator.pop(context);
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return BanDurationSheet(onDurationSelected: banFor);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user.name.isNotEmpty ? user.name : 'Без имени';
    final phone = user.phone.isNotEmpty ? user.phone : 'Не указан';
    final about = user.about.isNotEmpty ? user.about : 'Пока пусто';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final memberRoles =
            (data?['memberRoles'] as Map<String, dynamic>?) ?? {};
        final memberStatus =
            (data?['memberStatus'] as Map<String, dynamic>?) ?? {};

        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        final role = memberRoles[user.uid] ?? 'member';
        final roleTitle = RoleHelper.title(role);

        final statusData =
            (memberStatus[user.uid] as Map<String, dynamic>?) ??
            {'status': 'normal'};
        final status = statusData['status'] ?? 'normal';
        final statusTitle = StatusHelper.title(status);
        final statusDetails = StatusHelper.formatDetails(statusData);
        final statusIsActive = StatusHelper.isActive(statusData);
        final isMutedActive = status == 'muted' && statusIsActive;
        final isBannedActive = status == 'banned' && statusIsActive;

        final currentUserRole = memberRoles[currentUserId] ?? 'member';
        final isSelf = currentUserId == user.uid;
        final canClearExpiredStatus =
            currentUserRole == 'admin' || currentUserRole == 'owner';

        if (canClearExpiredStatus && !statusIsActive && status != 'normal') {
          ChatService().clearExpiredMemberStatus(
            chatId: chatId,
            userId: user.uid,
          );
        }

        final isCurrentUserOwner = currentUserRole == 'owner';
        final isCurrentUserAdmin = currentUserRole == 'admin';
        final isCurrentUserModerator = currentUserRole == 'moderator';

        final targetIsOwner = role == 'owner';
        final targetIsAdmin = role == 'admin';
        final isTargetGuest = role == 'guest';

        final canManage = !isSelf && (isCurrentUserOwner || isCurrentUserAdmin);

        final canMute =
            !isSelf &&
            (isCurrentUserOwner ||
                isCurrentUserAdmin ||
                isCurrentUserModerator) &&
            !targetIsOwner &&
            !targetIsAdmin;

        final canTransferAdmin =
            canManage && role != 'admin' && role != 'owner';

        final canModerate = canMute;
        final canBan =
            !isSelf &&
            (isCurrentUserOwner || isCurrentUserAdmin) &&
            !targetIsOwner &&
            !targetIsAdmin;

        return Scaffold(
          appBar: AppBar(title: const Text('Участник группы')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 48,
                child: Text(
                  displayName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  user.email,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Телефон'),
                  subtitle: Text(phone),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('О себе'),
                  subtitle: Text(about),
                ),
              ),
              if (!isSelf) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      HapticFeedback.selectionClick();

                      final chatId = await ChatService().getOrCreatePrivateChat(
                        user,
                      );

                      if (!context.mounted) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: chatId,
                            chatName: user.name.isNotEmpty
                                ? user.name
                                : user.email,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Написать'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Информация об участнике',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              MemberRoleCard(
                roleTitle: roleTitle,
                canManage: canManage,
                onEdit: () async {
                  final selectedRole = await showModalBottomSheet<String>(
                    context: context,
                    builder: (context) {
                      return RoleSelectionSheet(
                        canTransferAdmin: canTransferAdmin,
                        isCurrentUserOwner: isCurrentUserOwner,
                      );
                    },
                  );

                  if (!context.mounted) return;

                  if (selectedRole == 'transfer_admin') {
                    final shouldTransfer = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text(
                            'Передать права администратора $displayName?',
                          ),
                          content: Text(
                            '$displayName станет администратором.\n\n'
                            'Вы станете участником и сможете покинуть группу.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Передать'),
                            ),
                          ],
                        );
                      },
                    );

                    if (shouldTransfer == true) {
                      HapticFeedback.mediumImpact();

                      await ChatService().transferAdminRights(
                        chatId: chatId,
                        newAdminId: user.uid,
                      );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Права администратора переданы'),
                        ),
                      );
                    }

                    return;
                  }

                  if (selectedRole != null) {
                    HapticFeedback.selectionClick();
                    await updateRole(role: selectedRole);
                  }
                },
              ),
              if (status != 'normal' && statusIsActive)
                MemberStatusCard(
                  status: status,
                  statusTitle: statusTitle,
                  statusDetails: statusDetails,
                ),
              ModerationActionsSection(
                canModerate: canModerate,
                canBan: canBan,
                isTargetGuest: isTargetGuest,
                isMutedActive: isMutedActive,
                isBannedActive: isBannedActive,

                onMute: () => showMuteSheet(context),

                onUnmute: () async {
                  HapticFeedback.mediumImpact();

                  await ChatService().unmuteMember(
                    chatId: chatId,
                    userId: user.uid,
                  );
                },

                onBan: () => showBanSheet(context),

                onUnban: () async {
                  HapticFeedback.mediumImpact();

                  await ChatService().unbanMember(
                    chatId: chatId,
                    userId: user.uid,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
