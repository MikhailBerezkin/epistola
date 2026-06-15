import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/app_user.dart';
import '../services/chat_service.dart';

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
      case 'readOnly':
        return 'Только чтение';
      case 'banned':
        return 'Заблокирован';
      default:
        return 'Участник';
    }
  }

  Future<void> updateRole({required String role}) async {
    await ChatService().updateMemberRole(
      chatId: chatId,
      userId: user.uid,
      role: role,
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

        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        final role = memberRoles[user.uid] ?? 'member';
        final roleTitle = getRoleTitle(role);

        final currentUserRole = memberRoles[currentUserId] ?? 'member';
        final isSelf = currentUserId == user.uid;

        final isCurrentUserOwner = currentUserRole == 'owner';
        final isCurrentUserAdmin = currentUserRole == 'admin';
        final canManage = !isSelf && (isCurrentUserOwner || isCurrentUserAdmin);

        final targetIsOwner = role == 'owner';
        final targetIsAdmin = role == 'admin';

        final showAssignAdmin =
            canManage && isCurrentUserOwner && !targetIsOwner && !targetIsAdmin;

        final showAssignModerator =
            canManage &&
            !targetIsOwner &&
            !targetIsAdmin &&
            role != 'moderator';

        final showMakeMember =
            canManage &&
            !targetIsOwner &&
            role != 'member' &&
            (isCurrentUserOwner || role != 'admin');

        final showReadOnly =
            canManage && !targetIsOwner && !targetIsAdmin && role != 'readOnly';

        final showBan =
            canManage && !targetIsOwner && !targetIsAdmin && role != 'banned';

        final showManagementBlock =
            showAssignAdmin ||
            showAssignModerator ||
            showMakeMember ||
            showReadOnly ||
            showBan;

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
                ),
              ),
              if (showManagementBlock) ...[
                const SizedBox(height: 24),
                const Text(
                  'Управление участником',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
              ],
              if (showAssignAdmin)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Назначить администратором'),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await updateRole(role: 'admin');
                    },
                  ),
                ),
              if (showAssignModerator)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield),
                    title: const Text('Назначить модератором'),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await updateRole(role: 'moderator');
                    },
                  ),
                ),
              if (showMakeMember)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Сделать участником'),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await updateRole(role: 'member');
                    },
                  ),
                ),
              if (showReadOnly)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.visibility),
                    title: const Text('Только чтение'),
                    subtitle: const Text(
                      'Участник сможет читать, но не писать',
                    ),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await updateRole(role: 'readOnly');
                    },
                  ),
                ),
              if (showBan)
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
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await updateRole(role: 'banned');
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
