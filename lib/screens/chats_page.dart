import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/chat_service.dart';
import '../widgets/chat_tile.dart';
import 'chat_screen.dart';

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

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
          const Text(
            'Чаты',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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

                if (chats.isEmpty) {
                  return const Center(child: Text('Пока нет чатов'));
                }

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final data = chat.data() as Map<String, dynamic>;

                    final lastMessage = data['lastMessage'] ?? '';

                    return FutureBuilder<String>(
                      future: _getDisplayChatName(chatService, data),
                      builder: (context, nameSnapshot) {
                        final chatName =
                            nameSnapshot.data ?? data['name'] ?? 'Чат';

                        return ChatTile(
                          chatId: chat.id,
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
