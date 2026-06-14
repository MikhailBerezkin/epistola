import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../services/chat_service.dart';
import '../widgets/found_user_card.dart';
import '../widgets/user_search_input.dart';
import 'chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final searchController = TextEditingController();
  final chatService = ChatService();

  List<AppUser> foundUsers = [];
  bool isLoading = false;
  String? errorText;

  Future<void> searchUsers() async {
    final searchText = searchController.text.trim();

    if (searchText.isEmpty) {
      setState(() {
        foundUsers = [];
        errorText = 'Введите email или телефон пользователя';
      });
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      isLoading = true;
      foundUsers = [];
      errorText = null;
    });

    try {
      final users = await chatService.searchUsers(searchText);

      if (!mounted) return;

      setState(() {
        foundUsers = users;
        errorText = users.isEmpty ? 'Пользователь не найден' : null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        foundUsers = [];
        errorText = 'Ошибка поиска пользователя';
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> openChat(AppUser user) async {
    HapticFeedback.lightImpact();

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
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск пользователя')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            UserSearchInput(
              controller: searchController,
              isLoading: isLoading,
              onSearch: searchUsers,
            ),
            const SizedBox(height: 24),
            if (errorText != null)
              Text(
                errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (foundUsers.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: foundUsers.length,
                  itemBuilder: (context, index) {
                    final user = foundUsers[index];

                    return FoundUserCard(
                      user: user,
                      isLoading: isLoading,
                      onOpenChat: () => openChat(user),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
