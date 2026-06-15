import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/app_user.dart';
import '../services/chat_service.dart';
import 'group_member_screen.dart';
import 'add_members_screen.dart';

class GroupInfoScreen extends StatelessWidget {
  final String chatId;

  const GroupInfoScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return Scaffold(
      appBar: AppBar(title: const Text('Информация о группе')),
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

          final groupName = data['name'] ?? 'Группа';
          final memberIds = List<String>.from(data['memberIds'] ?? []);

          return FutureBuilder<List<AppUser>>(
            future: chatService.getUsersByIds(memberIds),
            builder: (context, usersSnapshot) {
              final users = usersSnapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 48,
                    child: Text(
                      groupName.toString().isNotEmpty
                          ? groupName.toString()[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      groupName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      '${memberIds.length} участников',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Настройки'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        debugPrint('Настройки группы');
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_add),
                      title: const Text('Добавить участника'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        HapticFeedback.selectionClick();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddMembersScreen(chatId: chatId),
                          ),
                        );
                      },
                    ),
                  ),

                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Покинуть группу',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        debugPrint('Покинуть группу');
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Участники',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (usersSnapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (users.isEmpty)
                    const Text('Участники не найдены')
                  else
                    ...users.map((user) {
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : user.email[0].toUpperCase(),
                          ),
                        ),
                        title: Text(
                          user.name.isNotEmpty ? user.name : 'Без имени',
                        ),
                        subtitle: Text(user.email),
                        onTap: () {
                          HapticFeedback.selectionClick();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  GroupMemberScreen(chatId: chatId, user: user),
                            ),
                          );
                        },
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
