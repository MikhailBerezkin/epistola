import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/chat_service.dart';
import '../widgets/chat_tile.dart';
import 'chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../services/chat/chat_peer_resolver.dart';
import '../services/chat/chat_peer_user_cache.dart';

class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key});

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final searchController = TextEditingController();
  final chatService = ChatService();

  late final ChatPeerUserCache _peerUserCache;

  String searchQuery = '';
  bool _isOpeningChat = false;

  @override
  void initState() {
    super.initState();
    _peerUserCache = ChatPeerUserCache(chatService.getUsersByIds);
  }

  bool matchesSearch(Map<String, dynamic> data) {
    if (searchQuery.isEmpty) return true;

    final chatName = (data['name'] ?? '').toString().toLowerCase();
    final lastMessage = (data['lastMessage'] ?? '').toString().toLowerCase();
    final query = searchQuery.toLowerCase();

    return chatName.contains(query) || lastMessage.contains(query);
  }

  Future<void> _openChat({
    required String chatId,
    required Map<String, dynamic> data,
    required String chatName,
  }) async {
    if (_isOpeningChat) return;

    HapticFeedback.lightImpact();

    setState(() {
      _isOpeningChat = true;
    });

    AppUser? peerUser;
    var resolvedChatName = chatName;

    if (data['type'] == 'private') {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final peerUserId = ChatPeerResolver.otherUserId(
        chatData: data,
        currentUserId: currentUserId,
      );

      if (peerUserId != null) {
        try {
          await _peerUserCache.loadMissing([peerUserId]);
          peerUser = _peerUserCache.usersById[peerUserId];
        } catch (_) {
          // Чат всё равно откроется без загруженной фотографии.
        }
      }

      final peerName = peerUser?.name.trim() ?? '';
      final peerEmail = peerUser?.email.trim() ?? '';

      if (peerName.isNotEmpty) {
        resolvedChatName = peerName;
      } else if (peerEmail.isNotEmpty) {
        resolvedChatName = peerEmail;
      } else {
        resolvedChatName = 'Личный чат';
      }
    }

    if (!mounted) return;

    setState(() {
      _isOpeningChat = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          chatName: resolvedChatName,
          peerUser: data['type'] == 'private' ? peerUser : null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          autofocus: true,
          onChanged: (value) {
            setState(() => searchQuery = value.trim());
          },
          decoration: InputDecoration(
            hintText: 'Поиск чатов',
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
            border: InputBorder.none,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
            padding: const EdgeInsets.all(16),
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
                  _openChat(chatId: chat.id, data: data, chatName: chatName);
                },
              );
            },
          );
        },
      ),
    );
  }
}
