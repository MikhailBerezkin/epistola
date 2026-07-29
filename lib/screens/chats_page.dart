import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/app_user.dart';
import '../services/chat/chat_peer_resolver.dart';
import '../services/chat/chat_peer_user_cache.dart';
import '../services/chat_service.dart';
import '../widgets/chat_tile.dart';
import 'chat_screen.dart';
import '../services/avatar/group_avatar_metadata_mapper.dart';

enum ChatFilter { private, group }

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  ChatFilter _selectedFilter = ChatFilter.private;
  late final ChatService _chatService;
  late final ChatPeerUserCache _peerUserCache;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    _peerUserCache = ChatPeerUserCache(_chatService.getUsersByIds);
  }

  void _loadMissingPeerUsers(Set<String> userIds) {
    _peerUserCache
        .loadMissing(userIds)
        .then((didLoad) {
          if (didLoad && mounted) {
            setState(() {});
          }
        })
        .catchError((Object _) {
          // The chat list keeps its name-based fallback. A later stream
          // rebuild can retry a transient user-profile read failure.
        });
  }

  String _getDisplayChatName(Map<String, dynamic> data, AppUser? peerUser) {
    final storedName = data['name'] is String
        ? data['name'] as String
        : data['type'] == 'private'
        ? 'Личный чат'
        : 'Без названия';

    if (data['type'] != 'private' || peerUser == null) {
      return storedName;
    }

    if (peerUser.name.isNotEmpty) {
      return peerUser.name;
    }

    return peerUser.email.isNotEmpty ? peerUser.email : storedName;
  }

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

  @override
  Widget build(BuildContext context) {
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
              stream: _chatService.getUserChats(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chats = snapshot.data?.docs ?? [];
                final currentUserId =
                    FirebaseAuth.instance.currentUser?.uid ?? '';

                final filteredChats = chats.where((chat) {
                  final data = chat.data() as Map<String, dynamic>;

                  final type = data['type'] ?? 'group';

                  if (_selectedFilter == ChatFilter.private) {
                    if (type != 'private') {
                      return false;
                    }

                    if (currentUserId.isEmpty) {
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

                final peerUserIds = ChatPeerResolver.collectOtherUserIds(
                  chats: filteredChats.map(
                    (chat) => chat.data() as Map<String, dynamic>,
                  ),
                  currentUserId: currentUserId,
                );

                _loadMissingPeerUsers(peerUserIds);

                return ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];

                    final data = chat.data() as Map<String, dynamic>;

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
                        currentUserId.isNotEmpty &&
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

                    final clearedAt = currentUserId.isEmpty
                        ? null
                        : clearedAtByUser[currentUserId];

                    final peerUser = ChatPeerResolver.resolveOtherUser(
                      chatData: data,
                      currentUserId: currentUserId,
                      usersById: _peerUserCache.usersById,
                    );

                    final chatName = _getDisplayChatName(data, peerUser);
                    final groupAvatar = data['type'] == 'group'
                        ? GroupAvatarMetadataMapper.fromMap(
                            data: data,
                            chatId: chat.id,
                          )
                        : null;

                    return FutureBuilder<({String text, Timestamp createdAt})?>(
                      future: showLastMessagePreview
                          ? null
                          : _chatService.findLatestVisibleMessagePreview(
                              chatId: chat.id,
                              after: clearedAt is Timestamp ? clearedAt : null,
                            ),
                      builder: (context, previewSnapshot) {
                        final fallbackPreview = previewSnapshot.data;

                        final effectiveLastMessage = showLastMessagePreview
                            ? lastMessage
                            : fallbackPreview?.text ?? '';

                        final effectiveLastMessageAt = showLastMessagePreview
                            ? data['lastMessageAt']
                            : fallbackPreview?.createdAt;

                        final hasEffectivePreview =
                            showLastMessagePreview || fallbackPreview != null;

                        return ChatTile(
                          chatId: chat.id,
                          chatName: chatName,
                          isPrivateChat: data['type'] == 'private',
                          peerUser: peerUser,
                          groupAvatar: groupAvatar,
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
                                  peerUser: data['type'] == 'private'
                                      ? peerUser
                                      : null,
                                ),
                              ),
                            );
                          },
                          onLongPress: _selectedFilter == ChatFilter.private
                              ? () {
                                  _confirmClearPrivateChat(
                                    chatService: _chatService,
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
            ),
          ),
        ],
      ),
    );
  }
}
