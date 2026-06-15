import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/app_user.dart';
import '../services/chat_service.dart';

class AddMembersScreen extends StatefulWidget {
  final String chatId;

  const AddMembersScreen({super.key, required this.chatId});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final chatService = ChatService();
  final selectedUsers = <String, AppUser>{};

  bool isLoading = false;

  void toggleUser(AppUser user) {
    setState(() {
      if (selectedUsers.containsKey(user.uid)) {
        selectedUsers.remove(user.uid);
      } else {
        selectedUsers[user.uid] = user;
      }
    });

    HapticFeedback.selectionClick();
  }

  Future<void> addMembers() async {
    if (selectedUsers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выберите участников')));
      return;
    }

    setState(() => isLoading = true);

    try {
      await chatService.addMembersToGroup(
        chatId: widget.chatId,
        members: selectedUsers.values.toList(),
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить участников')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedUsers.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Добавить участников')),
      body: FutureBuilder<List<AppUser>>(
        future: chatService.getUsersNotInGroup(widget.chatId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(child: Text('Некого добавить'));
          }

          return Column(
            children: [
              if (selectedCount > 0)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Выбрано: $selectedCount',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = selectedUsers.containsKey(user.uid);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (_) => toggleUser(user),
                      secondary: CircleAvatar(
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
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : addMembers,
                      icon: const Icon(Icons.person_add),
                      label: Text(isLoading ? 'Добавление...' : 'Добавить'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
