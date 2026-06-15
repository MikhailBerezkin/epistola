import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/app_user.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final groupNameController = TextEditingController();
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

  Future<void> createGroup() async {
    final groupName = groupNameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите название группы')));
      return;
    }

    HapticFeedback.lightImpact();

    setState(() => isLoading = true);

    try {
      final chatId = await chatService.createGroupChat(
        groupName,
        members: selectedUsers.values.toList(),
      );

      if (!mounted || chatId == null) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, chatName: groupName),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать группу')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedUsers.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Создать группу')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: groupNameController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Название группы',
                hintText: 'Например: Механики',
                prefixIcon: const Icon(Icons.group),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selectedCount == 0
                    ? 'Участники'
                    : 'Участники выбраны: $selectedCount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<AppUser>>(
                future: chatService.getAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data ?? [];

                  if (users.isEmpty) {
                    return const Center(
                      child: Text('Пока нет других пользователей'),
                    );
                  }

                  return ListView.builder(
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
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: isLoading ? null : createGroup,
                icon: const Icon(Icons.check),
                label: Text(isLoading ? 'Создание...' : 'Создать'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
