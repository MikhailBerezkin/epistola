import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/chat_service.dart';
import '../widgets/chat_tile.dart';
import 'chat_screen.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final searchController = TextEditingController();
  String searchQuery = '';

  bool matchesSearch(Map<String, dynamic> data) {
    if (searchQuery.isEmpty) return true;

    final chatName = (data['name'] ?? '').toString().toLowerCase();
    final lastMessage = (data['lastMessage'] ?? '').toString().toLowerCase();
    final query = searchQuery.toLowerCase();

    return chatName.contains(query) || lastMessage.contains(query);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: (value) {
              setState(() => searchQuery = value.trim());
            },
            decoration: InputDecoration(
              hintText: 'Поиск',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() => searchQuery = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
                final filteredChats = chats.where((chat) {
                  final data = chat.data() as Map<String, dynamic>;
                  return matchesSearch(data);
                }).toList();

                if (chats.isEmpty) {
                  return const Center(child: Text('Пока нет чатов'));
                }

                if (filteredChats.isEmpty) {
                  return const Center(child: Text('Ничего не найдено'));
                }

                return ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    final data = chat.data() as Map<String, dynamic>;

                    final chatName = data['name'] ?? 'Без названия';
                    final lastMessage = data['lastMessage'] ?? '';

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
                            builder: (_) =>
                                ChatScreen(chatId: chat.id, chatName: chatName),
                          ),
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
