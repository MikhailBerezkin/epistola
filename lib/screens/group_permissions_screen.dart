import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupPermissionsScreen extends StatelessWidget {
  final String chatId;

  const GroupPermissionsScreen({super.key, required this.chatId});

  String getMessagePermissionTitle(String permission) {
    switch (permission) {
      case 'moderators':
        return 'Модераторы и администраторы';
      case 'admins':
        return 'Только администраторы';
      default:
        return 'Все участники';
    }
  }

  Future<void> showComingSoon(BuildContext context) async {
    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Добавим позже')));
  }

  Future<void> showMessagePermissionSheet({
    required BuildContext context,
    required ChatService chatService,
  }) async {
    HapticFeedback.selectionClick();

    final selectedPermission = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Кто может писать сообщения',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Все участники'),
                onTap: () => Navigator.pop(context, 'all'),
              ),
              ListTile(
                leading: const Icon(Icons.shield),
                title: const Text('Модераторы и администраторы'),
                onTap: () => Navigator.pop(context, 'moderators'),
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Только администраторы'),
                onTap: () => Navigator.pop(context, 'admins'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedPermission != null) {
      await chatService.updateGroupMessagePermission(
        chatId: chatId,
        permission: selectedPermission,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(child: Text('Группа не найдена'));
          }
          final memberRoles =
              (data['memberRoles'] as Map<String, dynamic>?) ?? {};

          final currentUserRole = memberRoles[currentUser?.uid] ?? 'member';

          final canManageSettings =
              currentUserRole == 'admin' || currentUserRole == 'owner';

          final groupSettings =
              (data['groupSettings'] as Map<String, dynamic>?) ?? {};
          final messagePermission = groupSettings['messagePermission'] ?? 'all';
          final messagePermissionTitle = getMessagePermissionTitle(
            messagePermission,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Настройки группы',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.chat),
                  title: const Text('Кто может писать сообщения'),
                  subtitle: Text(messagePermissionTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: canManageSettings
                      ? () => showMessagePermissionSheet(
                          context: context,
                          chatService: chatService,
                        )
                      : null,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: const Text('Кто может отправлять файлы'),
                  subtitle: const Text('Добавим позже'),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: canManageSettings,
                  onTap: () => showComingSoon(context),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.photo),
                  title: const Text('Кто может отправлять фотографии'),
                  subtitle: const Text('Добавим позже'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showComingSoon(context),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_add_alt_1),
                  title: const Text('Кто может приглашать участников'),
                  subtitle: const Text('Добавим позже'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showComingSoon(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
