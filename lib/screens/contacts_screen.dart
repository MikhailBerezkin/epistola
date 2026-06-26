import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/app_user.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

enum ContactsSortMode { alphabet }

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  ContactsSortMode _sortMode = ContactsSortMode.alphabet;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _displayName(AppUser user) {
    return user.name.isNotEmpty ? user.name : 'Без имени';
  }

  String _subtitle(AppUser user) {
    if (user.phone.isNotEmpty) {
      return '${user.phone} • ${user.email}';
    }

    return user.email;
  }

  List<AppUser> _filterAndSortUsers(List<AppUser> users) {
    final normalizedQuery = _query.trim().toLowerCase();

    final filteredUsers = users.where((user) {
      if (normalizedQuery.isEmpty) return true;

      final name = user.name.toLowerCase();
      final email = user.email.toLowerCase();
      final phone = user.phone.toLowerCase();

      return name.contains(normalizedQuery) ||
          email.contains(normalizedQuery) ||
          phone.contains(normalizedQuery);
    }).toList();

    if (_sortMode == ContactsSortMode.alphabet) {
      filteredUsers.sort((a, b) {
        return _displayName(
          a,
        ).toLowerCase().compareTo(_displayName(b).toLowerCase());
      });
    }

    return filteredUsers;
  }

  Future<void> _openChat(AppUser user) async {
    HapticFeedback.lightImpact();

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final chatId = await _chatService.getOrCreatePrivateChat(user);

      if (!mounted) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(chatId: chatId, chatName: _displayName(user)),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось открыть чат: $error')),
      );
    }
  }

  void _showUserCard(AppUser user) {
    HapticFeedback.selectionClick();

    final displayName = _displayName(user);
    final phone = user.phone.isNotEmpty ? user.phone : 'Не указан';
    final about = user.about.isNotEmpty ? user.about : 'Пока пусто';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 42,
                  child: Text(
                    displayName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Телефон'),
                    subtitle: Text(phone),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('О себе'),
                    subtitle: Text(about),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openChat(user);
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Написать'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactTile(AppUser user) {
    final displayName = _displayName(user);

    return ListTile(
      leading: CircleAvatar(child: Text(displayName[0].toUpperCase())),
      title: Text(displayName),
      subtitle: Text(_subtitle(user)),
      onTap: () => _showUserCard(user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.menu_book_outlined),
            SizedBox(width: 12),
            Text('Контакты'),
          ],
        ),
        actions: [
          PopupMenuButton<ContactsSortMode>(
            icon: const Icon(Icons.sort),
            tooltip: 'Сортировка',
            onSelected: (value) {
              HapticFeedback.selectionClick();

              setState(() {
                _sortMode = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ContactsSortMode.alphabet,
                child: Text('По алфавиту'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<AppUser>>(
        future: _chatService.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data ?? [];
          final visibleUsers = _filterAndSortUsers(users);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Поиск по имени, email или телефону',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();

                              setState(() {
                                _query = '';
                              });
                            },
                          ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
              ),
              const Divider(height: 1),
              if (visibleUsers.isEmpty)
                const Expanded(
                  child: Center(child: Text('Пользователи не найдены')),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: visibleUsers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _buildContactTile(visibleUsers[index]);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
