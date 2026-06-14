import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

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

  bool isLoading = false;

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
      final chatId = await chatService.createGroupChat(groupName);

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
    return Scaffold(
      appBar: AppBar(title: const Text('Создать группу')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: groupNameController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => createGroup(),
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
