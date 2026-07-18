import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_base_service.dart';
import '../../domain/value_objects/message_text.dart';

class ChatMessagesService extends ChatBaseService {
  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final user = auth.currentUser;
    if (user == null) return;
    final message = MessageText.tryParse(text);
    if (message == null) return;

    final normalizedText = message.value;

    final chatRef = firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data();

    if (chatData == null) {
      return;
    }

    final chatType = chatData['type'] ?? 'private';
    final isGroup = chatType == 'group';
    final isDissolved = chatData['isDissolved'] == true;

    if (isDissolved) {
      return;
    }

    if (isGroup) {
      final memberRoles =
          (chatData['memberRoles'] as Map<String, dynamic>?) ?? {};

      final memberStatus =
          (chatData['memberStatus'] as Map<String, dynamic>?) ?? {};

      final role = memberRoles[user.uid] ?? 'member';
      final statusData =
          (memberStatus[user.uid] as Map<String, dynamic>?) ??
          {'status': 'normal'};

      var status = statusData['status'] ?? 'normal';
      final permanent = statusData['permanent'] == true;
      final expiresAt = statusData['expiresAt'];

      final statusIsActive =
          permanent ||
          (expiresAt is Timestamp &&
              expiresAt.toDate().isAfter(DateTime.now()));

      if ((status == 'muted' || status == 'banned') &&
          !statusIsActive &&
          expiresAt is Timestamp) {
        try {
          await _clearExpiredMemberStatus(chatId: chatId, userId: user.uid);
        } catch (_) {
          // Firestore rules may reject self-cleanup.
          // The expired status is still treated as normal locally.
        }

        status = 'normal';
      }

      final groupSettings =
          (chatData['groupSettings'] as Map<String, dynamic>?) ?? {};
      final messagePermission = groupSettings['messagePermission'] ?? 'all';

      final canWriteByGroupPermission =
          messagePermission == 'all' ||
          (messagePermission == 'moderators' &&
              (role == 'moderator' || role == 'admin' || role == 'owner')) ||
          (messagePermission == 'admins' &&
              (role == 'admin' || role == 'owner'));

      final isGuest = role == 'guest';
      final isMuted = status == 'muted' && statusIsActive;
      final isBanned = status == 'banned' && statusIsActive;

      if (isGuest || isMuted || isBanned || !canWriteByGroupPermission) {
        return;
      }
    }

    final userDoc = await firestore.collection('users').doc(user.uid).get();

    final senderName = (userDoc.data()?['name'] as String?) ?? '';
    final messageRef = chatRef.collection('messages').doc();

    final messageData = <String, dynamic>{
      'text': normalizedText,
      'senderId': user.uid,
      'senderEmail': user.email,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final batch = firestore.batch();

    batch.set(messageRef, messageData);
    batch.update(chatRef, {
      'lastMessage': normalizedText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageId': messageRef.id,
    });

    await batch.commit();
  }

  Stream<QuerySnapshot> getMessages(String chatId, {Timestamp? after}) {
    Query query = firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages');

    if (after != null) {
      query = query.where('createdAt', isGreaterThan: after);
    }

    return query.orderBy('createdAt').snapshots();
  }

  Future<void> markChatAsRead(String chatId) async {
    final user = auth.currentUser;
    if (user == null) return;

    await firestore.collection('chats').doc(chatId).set({
      'lastRead': {user.uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  Future<int> getUnreadCount(String chatId) async {
    final user = auth.currentUser;
    if (user == null) return 0;

    final chatDoc = await firestore.collection('chats').doc(chatId).get();

    final data = chatDoc.data();
    if (data == null) return 0;

    final lastReadMap = (data['lastRead'] as Map<String, dynamic>?) ?? {};
    final lastRead = lastReadMap[user.uid];

    Query query = firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages');

    if (lastRead is Timestamp) {
      query = query.where('createdAt', isGreaterThan: lastRead);
    }

    final snapshot = await query.get();

    return snapshot.docs.where((doc) {
      final senderId = doc['senderId'];
      return senderId != user.uid;
    }).length;
  }

  Future<void> _clearExpiredMemberStatus({
    required String chatId,
    required String userId,
  }) async {
    final chatDoc = await firestore.collection('chats').doc(chatId).get();
    final data = chatDoc.data();

    if (data == null) return;

    final memberStatus = (data['memberStatus'] as Map<String, dynamic>?) ?? {};
    final statusData = (memberStatus[userId] as Map<String, dynamic>?) ?? {};

    final status = statusData['status'];
    final permanent = statusData['permanent'] == true;
    final expiresAt = statusData['expiresAt'];

    if (status != 'muted' && status != 'banned') return;
    if (permanent) return;
    if (expiresAt is! Timestamp) return;

    final isExpired = expiresAt.toDate().isBefore(DateTime.now());

    if (!isExpired) return;

    await firestore.collection('chats').doc(chatId).update({
      'memberStatus.$userId': {'status': 'normal'},
    });
  }
}
