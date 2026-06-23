import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/app_user.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class GroupMemberScreen extends StatelessWidget {
  final String chatId;
  final AppUser user;

  const GroupMemberScreen({
    super.key,
    required this.chatId,
    required this.user,
  });

  String getRoleTitle(String role) {
    switch (role) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'moderator':
        return 'Модератор';
      case 'guest':
        return 'Гость';
      default:
        return 'Участник';
    }
  }

  String getStatusTitle(String status) {
    switch (status) {
      case 'muted':
        return 'Мьют';
      case 'banned':
        return 'Бан';
      default:
        return 'Нормальный';
    }
  }

  bool isStatusActive(Map<String, dynamic> statusData) {
    final permanent = statusData['permanent'] == true;
    final expiresAt = statusData['expiresAt'];

    if (permanent) return true;

    if (expiresAt is Timestamp) {
      return expiresAt.toDate().isAfter(DateTime.now());
    }

    return false;
  }

  String formatStatusDetails(Map<String, dynamic> statusData) {
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

  Future<void> updateRole({required String role}) async {
    await ChatService().updateMemberRole(
      chatId: chatId,
      userId: user.uid,
      role: role,
    );
  }

  Future<void> showMuteSheet(BuildContext context) async {
    final service = ChatService();

    Future<void> muteFor(Duration? duration) async {
      HapticFeedback.mediumImpact();

      final expiresAt = duration == null ? null : DateTime.now().add(duration);

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
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Выдать мьют',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Причина: Флуд'),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('5 минут'),
                onTap: () => muteFor(const Duration(minutes: 5)),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('30 минут'),
                onTap: () => muteFor(const Duration(minutes: 30)),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('1 час'),
                onTap: () => muteFor(const Duration(hours: 1)),
              ),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('1 день'),
                onTap: () => muteFor(const Duration(days: 1)),
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('7 дней'),
                onTap: () => muteFor(const Duration(days: 7)),
              ),
            ],
          ),
        );
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
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Забанить участника',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Причина: Нарушение правил'),
              ),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('1 день'),
                onTap: () => banFor(const Duration(days: 1)),
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('7 дней'),
                onTap: () => banFor(const Duration(days: 7)),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('30 дней'),
                onTap: () => banFor(const Duration(days: 30)),
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('Навсегда'),
                onTap: () => banFor(null),
              ),
            ],
          ),
        );
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
        final roleTitle = getRoleTitle(role);

        final statusData =
            (memberStatus[user.uid] as Map<String, dynamic>?) ??
            {'status': 'normal'};
        final status = statusData['status'] ?? 'normal';
        final statusTitle = getStatusTitle(status);
        final statusDetails = formatStatusDetails(statusData);
        final statusIsActive = isStatusActive(statusData);

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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Роль'),
                  subtitle: Text(roleTitle),
                  trailing: canManage
                      ? IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final selectedRole =
                                await showModalBottomSheet<String>(
                                  context: context,
                                  builder: (context) {
                                    return SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const ListTile(
                                            title: Text(
                                              'Выберите роль',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.visibility,
                                            ),
                                            title: const Text('Гость'),
                                            onTap: () =>
                                                Navigator.pop(context, 'guest'),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.person),
                                            title: const Text('Участник'),
                                            onTap: () => Navigator.pop(
                                              context,
                                              'member',
                                            ),
                                          ),
                                          if (canTransferAdmin) ...[
                                            const Divider(),
                                            ListTile(
                                              leading: Icon(
                                                Icons.workspace_premium,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                              ),
                                              title: Text(
                                                'Передать права администратора',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              onTap: () => Navigator.pop(
                                                context,
                                                'transfer_admin',
                                              ),
                                            ),
                                          ],
                                          ListTile(
                                            leading: const Icon(Icons.shield),
                                            title: const Text('Модератор'),
                                            onTap: () => Navigator.pop(
                                              context,
                                              'moderator',
                                            ),
                                          ),
                                          if (isCurrentUserOwner)
                                            ListTile(
                                              leading: const Icon(
                                                Icons.admin_panel_settings,
                                              ),
                                              title: const Text(
                                                'Администратор',
                                              ),
                                              onTap: () => Navigator.pop(
                                                context,
                                                'admin',
                                              ),
                                            ),
                                        ],
                                      ),
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
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Отмена'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
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
                                    content: Text(
                                      'Права администратора переданы',
                                    ),
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
                        )
                      : null,
                ),
              ),
              if (status != 'normal' && statusIsActive)
                Card(
                  child: ListTile(
                    leading: Icon(
                      status == 'banned' ? Icons.block : Icons.volume_off,
                    ),
                    title: Text(statusTitle),
                    subtitle: statusDetails.isEmpty
                        ? null
                        : Text(statusDetails),
                  ),
                ),
              if (canModerate) ...[
                const SizedBox(height: 24),
                const Text(
                  'Модерация',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (!isTargetGuest && status != 'muted' && status != 'banned')
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.volume_off),
                      title: const Text('Выдать мьют'),
                      subtitle: const Text(
                        'Пользователь сможет читать, но не писать',
                      ),
                      onTap: () => showMuteSheet(context),
                    ),
                  ),
                if (status == 'muted')
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.volume_up),
                      title: const Text('Снять мьют'),
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await ChatService().unmuteMember(
                          chatId: chatId,
                          userId: user.uid,
                        );
                      },
                    ),
                  ),
                if (canBan && status != 'banned')
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.block,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Забанить',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onTap: () => showBanSheet(context),
                    ),
                  ),
                if (canBan && status == 'banned')
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_open),
                      title: const Text('Разбанить'),
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await ChatService().unbanMember(
                          chatId: chatId,
                          userId: user.uid,
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
