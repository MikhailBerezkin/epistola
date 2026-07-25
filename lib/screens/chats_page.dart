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

  Future<void> _confirmClearPrivateChat({
    required ChatService chatService,
    required String chatId,
    required String chatName,
  }) async {
    HapticFeedback.mediumImpact();

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить чат?'),
          content: Text('История с «$chatName» будет скрыта только для вас.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true || !mounted) return;

    try {
      await chatService.clearPrivateChatForCurrentUser(chatId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Чат скрыт только для вас')));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось удалить чат')));
    }
  }

  Future<String> _getDisplayChatName(
    ChatService chatService,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'] ?? 'group';

    if (type != 'private') {
      return data['name'] is String ? data['name'] as String : 'Без названия';
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
          const Row(
            children: [
              Expanded(
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
                    if (type != 'private') {
                      return false;
                    }

                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;

                    if (currentUserId == null) {
                      return false;
                    }

                    final clearedAtByUser =
                        (data['clearedAtByUser'] as Map<String, dynamic>?) ??
                        {};

                    final clearedAt = clearedAtByUser[currentUserId];

                    final lastMessageAt = data['lastMessageAt'];

                    if (clearedAt is Timestamp) {
                      if (lastMessageAt is! Timestamp) {
                        return false;
                      }

                      final hasNewMessage = lastMessageAt.toDate().isAfter(
                        clearedAt.toDate(),
                      );

                      if (!hasNewMessage) {
                        return false;
                      }
                    }

                    return true;
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

                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;

                    final lastMessage = data['lastMessage'] is String
                        ? data['lastMessage'] as String
                        : '';

                    final lastMessageId = data['lastMessageId'] is String
                        ? data['lastMessageId'] as String
                        : '';

                    final lastMessageHiddenFor =
                        (data['lastMessageHiddenFor']
                            as Map<String, dynamic>?) ??
                        {};

                    final isLastMessageHiddenForCurrentUser =
                        currentUserId != null &&
                        lastMessageId.isNotEmpty &&
                        lastMessageHiddenFor[currentUserId] == lastMessageId;

                    final isLastMessageDeletedForEveryone =
                        lastMessageId.isNotEmpty &&
                        data['lastMessageDeletedForEveryoneId'] ==
                            lastMessageId;

                    final showLastMessagePreview =
                        !isLastMessageHiddenForCurrentUser &&
                        !isLastMessageDeletedForEveryone;

                    final clearedAtByUser =
                        (data['clearedAtByUser'] as Map<String, dynamic>?) ??
                        {};

                    final clearedAt = currentUserId == null
                        ? null
                        : clearedAtByUser[currentUserId];

                    return FutureBuilder<String>(
                      future: _getDisplayChatName(chatService, data),
                      builder: (context, nameSnapshot) {
                        final chatName =
                            nameSnapshot.data ??
                            (data['name'] is String
                                ? data['name'] as String
                                : 'Чат');

                        return FutureBuilder<
                          ({String text, Timestamp createdAt})?
                        >(
                          future: showLastMessagePreview
                              ? null
                              : chatService.findLatestVisibleMessagePreview(
                                  chatId: chat.id,
                                  after: clearedAt is Timestamp
                                      ? clearedAt
                                      : null,
                                ),
                          builder: (context, previewSnapshot) {
                            final fallbackPreview = previewSnapshot.data;

                            final effectiveLastMessage = showLastMessagePreview
                                ? lastMessage
                                : fallbackPreview?.text ?? '';

                            final effectiveLastMessageAt =
                                showLastMessagePreview
                                ? data['lastMessageAt']
                                : fallbackPreview?.createdAt;

                            final hasEffectivePreview =
                                showLastMessagePreview ||
                                fallbackPreview != null;

                            return ChatTile(
                              chatId: chat.id,
                              chatName: chatName,
                              lastMessage: effectiveLastMessage,
                              lastMessageAt: effectiveLastMessageAt,
                              showLastMessagePreview: hasEffectivePreview,
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
                              onLongPress: _selectedFilter == ChatFilter.private
                                  ? () {
                                      _confirmClearPrivateChat(
                                        chatService: chatService,
                                        chatId: chat.id,
                                        chatName: chatName,
                                      );
                                    }
                                  : null,
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
