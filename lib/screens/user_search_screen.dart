import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final searchController = TextEditingController();
  final chatService = ChatService();

  AppUser? foundUser;
  bool isLoading = false;
  String? errorText;

  Future<void> searchUser() async {
    final searchText = searchController.text.trim();

    if (searchText.isEmpty) {
      setState(() {
        foundUser = null;
        errorText = 'Введите email или телефон пользователя';
      });
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      isLoading = true;
      foundUser = null;
      errorText = null;
    });

    try {
      final user = await chatService.findUserByEmailOrPhone(searchText);

      if (!mounted) return;

      setState(() {
        foundUser = user;
        errorText = user == null ? 'Пользователь не найден' : null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка поиска пользователя';
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> openChat() async {
    HapticFeedback.lightImpact();

    final user = foundUser;
    if (user == null) return;

    setState(() => isLoading = true);

    try {
      final chatId = await chatService.getOrCreatePrivateChat(user);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            chatName: user.name.isNotEmpty ? user.name : user.email,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось открыть чат')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = foundUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Поиск пользователя')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => searchUser(),
              decoration: InputDecoration(
                hintText: 'Введите email или телефон',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: isLoading ? null : searchUser,
                icon: const Icon(Icons.search),
                label: Text(isLoading ? 'Поиск...' : 'Найти'),
              ),
            ),
            const SizedBox(height: 24),
            if (errorText != null)
              Text(
                errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (user != null)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : user.email[0].toUpperCase(),
                    ),
                  ),
                  title: Text(user.name.isNotEmpty ? user.name : 'Без имени'),
                  subtitle: Text(user.email),
                  trailing: FilledButton(
                    onPressed: isLoading ? null : openChat,
                    child: const Text('Написать'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
