import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'private_chat_draft_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  late final Future<List<AppUser>> _usersFuture;

  String _query = '';
  bool _isOpeningChat = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = _chatService.getAllUsers();
  }

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

    filteredUsers.sort((a, b) {
      return _displayName(
        a,
      ).toLowerCase().compareTo(_displayName(b).toLowerCase());
    });

    return filteredUsers;
  }

  Future<void> _openChat(AppUser user) async {
    if (_isOpeningChat) return;

    HapticFeedback.lightImpact();

    setState(() => _isOpeningChat = true);

    try {
      final chatId = _chatService.getPrivateChatId(user);
      final chatExists = await _chatService.privateChatExists(chatId);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) {
            if (chatExists) {
              return ChatScreen(chatId: chatId, chatName: _displayName(user));
            }

            return PrivateChatDraftScreen(otherUser: user);
          },
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось открыть чат')));
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  Widget _buildUserTile(AppUser user) {
    final displayName = _displayName(user);

    return ListTile(
      enabled: !_isOpeningChat,
      leading: CircleAvatar(child: Text(displayName[0].toUpperCase())),
      title: Text(displayName),
      subtitle: Text(_subtitle(user)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openChat(user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск пользователя')),
      body: FutureBuilder<List<AppUser>>(
        future: _usersFuture,
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
                  enabled: !_isOpeningChat,
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
                      return _buildUserTile(visibleUsers[index]);
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
