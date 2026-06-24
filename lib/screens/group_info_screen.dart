import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../models/app_user.dart';
import '../services/chat_service.dart';
import 'add_members_screen.dart';
import 'group_settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/group/group_header.dart';
import '../widgets/group/group_settings_card.dart';
import '../widgets/group/add_members_card.dart';
import '../widgets/group/group_members_section.dart';
import '../widgets/group/leave_group_card.dart';
import '../widgets/group/dissolve_group_card.dart';

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
          final memberRoles =
              (data['memberRoles'] as Map<String, dynamic>?) ?? {};
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          final currentUserRole = memberRoles[currentUserId] ?? 'member';

          final canManageGroup =
              currentUserRole == 'admin' || currentUserRole == 'owner';
          final groupSettings =
              (data['groupSettings'] as Map<String, dynamic>?) ?? {};
          final messagePermission = groupSettings['messagePermission'] ?? 'all';

          final memberStatus =
              (data['memberStatus'] as Map<String, dynamic>?) ?? {};

          final currentStatusData =
              (memberStatus[currentUserId] as Map<String, dynamic>?) ??
              {'status': 'normal'};

          final currentStatus = currentStatusData['status'] ?? 'normal';

          final canAddMembers =
              currentUserRole != 'guest' &&
              currentStatus != 'muted' &&
              currentStatus != 'banned' &&
              ((messagePermission == 'all' &&
                      (currentUserRole == 'member' ||
                          currentUserRole == 'moderator' ||
                          currentUserRole == 'admin' ||
                          currentUserRole == 'owner')) ||
                  (messagePermission == 'moderators' &&
                      (currentUserRole == 'moderator' ||
                          currentUserRole == 'admin' ||
                          currentUserRole == 'owner')) ||
                  (messagePermission == 'admins' &&
                      (currentUserRole == 'admin' ||
                          currentUserRole == 'owner')));

          return FutureBuilder<List<AppUser>>(
            future: chatService.getUsersByIds(memberIds),
            builder: (context, usersSnapshot) {
              final users = List<AppUser>.from(usersSnapshot.data ?? []);

              users.sort((a, b) {
                final aName = a.name.isNotEmpty ? a.name : a.email;
                final bName = b.name.isNotEmpty ? b.name : b.email;
                return aName.toLowerCase().compareTo(bName.toLowerCase());
              });

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GroupHeader(
                    groupName: groupName,
                    memberCount: memberIds.length,
                  ),
                  if (canManageGroup)
                    GroupSettingsCard(
                      onTap: () {
                        HapticFeedback.selectionClick();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupSettingsScreen(chatId: chatId),
                          ),
                        );
                      },
                    ),
                  if (canAddMembers)
                    AddMembersCard(
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
                  LeaveGroupCard(
                    onTap: () async {
                      HapticFeedback.mediumImpact();

                      final shouldLeave = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Покинуть группу?'),
                            content: const Text(
                              'Вы больше не будете видеть эту группу в списке чатов.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Покинуть'),
                              ),
                            ],
                          );
                        },
                      );

                      if (shouldLeave != true) return;

                      final left = await chatService.leaveGroupSafely(chatId);

                      if (!context.mounted) return;

                      if (!left) {
                        await showDialog<void>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Вы последний администратор'),
                              content: const Text(
                                'Перед выходом нужно передать права администратора другому участнику или распустить группу.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Понятно'),
                                ),
                              ],
                            );
                          },
                        );

                        return;
                      }

                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                  ),

                  if (canManageGroup)
                    DissolveGroupCard(
                      onTap: () async {
                        HapticFeedback.heavyImpact();

                        final shouldDissolve = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Распустить группу?'),
                              content: const Text(
                                'Группа будет закрыта для всех участников.\n\n'
                                'История сообщений пока не удаляется.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Отмена'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Распустить'),
                                ),
                              ],
                            );
                          },
                        );

                        if (shouldDissolve != true) return;

                        await chatService.dissolveGroup(chatId);

                        if (!context.mounted) return;

                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                    ),

                  const SizedBox(height: 24),
                  GroupMembersSection(
                    chatId: chatId,
                    users: users,
                    memberRoles: memberRoles,
                    isLoading:
                        usersSnapshot.connectionState ==
                        ConnectionState.waiting,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
