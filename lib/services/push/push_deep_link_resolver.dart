import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/push_deep_link_request.dart';
import '../../models/app_user.dart';
import '../chat/chat_peer_resolver.dart';

typedef PushDeepLinkCurrentUserIdProvider = String? Function();

typedef PushDeepLinkChatLoader =
    Future<Map<String, dynamic>?> Function(String chatId);

typedef PushDeepLinkUserLoader = Future<AppUser?> Function(String userId);

enum PushDeepLinkChatType { private, group }

class PushDeepLinkDestination {
  const PushDeepLinkDestination({
    required this.chatId,
    required this.chatName,
    required this.chatType,
    this.peerUser,
  });

  final String chatId;
  final String chatName;
  final PushDeepLinkChatType chatType;
  final AppUser? peerUser;

  bool get isPrivateChat => chatType == PushDeepLinkChatType.private;
}

class PushDeepLinkResolver {
  PushDeepLinkResolver({
    required PushDeepLinkCurrentUserIdProvider currentUserIdProvider,
    required PushDeepLinkChatLoader loadChat,
    required PushDeepLinkUserLoader loadUser,
  }) : this._(
         currentUserIdProvider: currentUserIdProvider,
         loadChat: loadChat,
         loadUser: loadUser,
       );

  PushDeepLinkResolver._({
    required this._currentUserIdProvider,
    required this._loadChat,
    required this._loadUser,
  });

  factory PushDeepLinkResolver.firebase({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) {
    final effectiveAuth = auth ?? FirebaseAuth.instance;
    final effectiveFirestore = firestore ?? FirebaseFirestore.instance;

    return PushDeepLinkResolver(
      currentUserIdProvider: () => effectiveAuth.currentUser?.uid,
      loadChat: (chatId) async {
        final snapshot = await effectiveFirestore
            .collection('chats')
            .doc(chatId)
            .get();

        return snapshot.data();
      },
      loadUser: (userId) async {
        final snapshot = await effectiveFirestore
            .collection('users')
            .doc(userId)
            .get();

        if (!snapshot.exists) {
          return null;
        }

        return AppUser.fromFirestore(snapshot);
      },
    );
  }

  final PushDeepLinkCurrentUserIdProvider _currentUserIdProvider;
  final PushDeepLinkChatLoader _loadChat;
  final PushDeepLinkUserLoader _loadUser;

  Future<PushDeepLinkDestination?> resolve(PushDeepLinkRequest request) async {
    final currentUserId = _currentUserIdProvider()?.trim() ?? '';

    if (currentUserId.isEmpty) {
      return null;
    }

    final chatData = await _loadChat(request.chatId);

    if (chatData == null ||
        !_containsMember(chatData: chatData, currentUserId: currentUserId)) {
      return null;
    }

    final rawType = chatData['type'];
    final chatType = rawType is String ? rawType.trim() : 'group';

    if (chatType == 'private') {
      return _resolvePrivateChat(
        request: request,
        chatData: chatData,
        currentUserId: currentUserId,
      );
    }

    if (chatType == 'group') {
      return PushDeepLinkDestination(
        chatId: request.chatId,
        chatName: _readChatName(chatData, fallback: 'Без названия'),
        chatType: PushDeepLinkChatType.group,
      );
    }

    return null;
  }

  Future<PushDeepLinkDestination?> _resolvePrivateChat({
    required PushDeepLinkRequest request,
    required Map<String, dynamic> chatData,
    required String currentUserId,
  }) async {
    final peerUserId = ChatPeerResolver.otherUserId(
      chatData: chatData,
      currentUserId: currentUserId,
    );

    if (peerUserId == null) {
      return null;
    }

    final peerUser = await _loadUser(peerUserId);

    return PushDeepLinkDestination(
      chatId: request.chatId,
      chatName: _privateChatName(chatData: chatData, peerUser: peerUser),
      chatType: PushDeepLinkChatType.private,
      peerUser: peerUser,
    );
  }

  static bool _containsMember({
    required Map<String, dynamic> chatData,
    required String currentUserId,
  }) {
    final memberIds = chatData['memberIds'];

    if (memberIds is! Iterable) {
      return false;
    }

    for (final value in memberIds) {
      if (value is String && value.trim() == currentUserId) {
        return true;
      }
    }

    return false;
  }

  static String _privateChatName({
    required Map<String, dynamic> chatData,
    required AppUser? peerUser,
  }) {
    final peerName = peerUser?.name.trim() ?? '';

    if (peerName.isNotEmpty) {
      return peerName;
    }

    final peerEmail = peerUser?.email.trim() ?? '';

    if (peerEmail.isNotEmpty) {
      return peerEmail;
    }

    return _readChatName(chatData, fallback: 'Личный чат');
  }

  static String _readChatName(
    Map<String, dynamic> chatData, {
    required String fallback,
  }) {
    final value = chatData['name'];

    if (value is! String) {
      return fallback;
    }

    final name = value.trim();

    return name.isEmpty ? fallback : name;
  }
}
