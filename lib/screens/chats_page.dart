import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/chat_service.dart';
import '../widgets/chat_tile.dart';
import 'chat_screen.dart';

enum ChatFilter { private, group }

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  ChatFilter _selectedFilter = ChatFilter.private;

  Future<String> _getDisplayChatName(
    ChatService chatService,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'] ?? 'group';

    if (type != 'private') {
      return data['name'] ?? 'Без названия';
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final memberIds = List<String>.from(data['memberIds'] ?? []);

    if (currentUserId == null || memberIds.isEmpty) {
      return 'Личный чат';
    }

    final otherUserId = memberIds.firstWhere(
      (uid) => uid != currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) {
      return 'Личный чат';
    }

    final users = await chatService.getUsersByIds([otherUserId]);

    if (users.isEmpty) {
      return 'Личный чат';
    }

    final otherUser = users.first;

    if (otherUser.name.isNotEmpty) {
      return otherUser.name;
    }

    return otherUser.email;
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Чаты',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<ChatFilter>(
            segments: const [
              ButtonSegment(
                value: ChatFilter.private,
                label: Text('Личные'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: ChatFilter.group,
                label: Text('Группы'),
                icon: Icon(Icons.groups_outlined),
              ),
            ],
            selected: {_selectedFilter},
            onSelectionChanged: (selected) {
              HapticFeedback.selectionClick();

              setState(() {
                _selectedFilter = selected.first;
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatService.getUserChats(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chats = snapshot.data?.docs ?? [];

                final filteredChats = chats.where((chat) {
                  final data = chat.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'group';

                  if (_selectedFilter == ChatFilter.private) {
                    return type == 'private';
                  }

                  return type == 'group';
                }).toList();

                if (filteredChats.isEmpty) {
                  final message = _selectedFilter == ChatFilter.private
                      ? 'Пока нет личных чатов'
                      : 'Пока нет групп';

                  return Center(child: Text(message));
                }

                return ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    final data = chat.data() as Map<String, dynamic>;

                    final lastMessage = data['lastMessage'] ?? '';

                    return FutureBuilder<String>(
                      future: _getDisplayChatName(chatService, data),
                      builder: (context, nameSnapshot) {
                        final chatName =
                            nameSnapshot.data ?? data['name'] ?? 'Чат';

                        return ChatTile(
                          chatId: chat.id,
                          avatarUrl:
                              data['avatarThumbUrl'] ?? data['avatarUrl'] ?? '',
                          chatName: chatName,
                          lastMessage: lastMessage,
                          lastMessageAt: data['lastMessageAt'],
                          onTap: () {
                            HapticFeedback.lightImpact();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  chatId: chat.id,
                                  chatName: chatName,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
