import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> createGroupChat(
    String name, {
    List<AppUser> members = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final memberIds = <String>{user.uid};
    final memberEmails = <String>{if (user.email != null) user.email!};
    final memberRoles = <String, String>{user.uid: 'admin'};
    final memberStatus = <String, Map<String, dynamic>>{
      user.uid: {'status': 'normal'},
    };

    for (final member in members) {
      memberIds.add(member.uid);
      memberEmails.add(member.email);
      memberRoles[member.uid] = 'member';
      memberStatus[member.uid] = {'status': 'normal'};
    }

    final chatRef = await _firestore.collection('chats').add({
      'name': name,
      'type': 'group',
      'memberIds': memberIds.toList(),
      'memberEmails': memberEmails.toList(),
      'memberRoles': memberRoles,
      'memberStatus': memberStatus,
      'groupSettings': {'messagePermission': 'all'},
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageAt': null,
      'lastRead': {user.uid: FieldValue.serverTimestamp()},
    });

    return chatRef.id;
  }

  Future<List<AppUser>> getUsersNotInGroup(String chatId) async {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final data = chatDoc.data();

    if (data == null) return [];

    final memberIds = List<String>.from(data['memberIds'] ?? []);
    final allUsers = await getAllUsers();

    return allUsers.where((user) => !memberIds.contains(user.uid)).toList();
  }

  Future<void> addMembersToGroup({
    required String chatId,
    required List<AppUser> members,
  }) async {
    if (members.isEmpty) return;

    final memberIds = members.map((user) => user.uid).toList();
    final memberEmails = members.map((user) => user.email).toList();

    final memberUpdates = <String, dynamic>{};

    for (final member in members) {
      memberUpdates['memberRoles.${member.uid}'] = 'member';
      memberUpdates['memberStatus.${member.uid}'] = {'status': 'normal'};
    }

    await _firestore.collection('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayUnion(memberIds),
      'memberEmails': FieldValue.arrayUnion(memberEmails),
      ...memberUpdates,
    });
  }

  Future<void> updateMemberRole({
    required String chatId,
    required String userId,
    required String role,
  }) async {
    await _firestore.collection('chats').doc(chatId).update({
      'memberRoles.$userId': role,
    });
  }

  Future<void> updateGroupMessagePermission({
    required String chatId,
    required String permission,
  }) async {
    await _firestore.collection('chats').doc(chatId).set({
      'groupSettings': {'messagePermission': permission},
    }, SetOptions(merge: true));
  }

  Future<void> muteMember({
    required String chatId,
    required String userId,
    required String reason,
    DateTime? expiresAt,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('chats').doc(chatId).update({
      'memberStatus.$userId': {
        'status': 'muted',
        'reason': reason,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
        'permanent': expiresAt == null,
      },
    });
  }

  Future<void> unmuteMember({
    required String chatId,
    required String userId,
  }) async {
    await _firestore.collection('chats').doc(chatId).update({
      'memberStatus.$userId': {'status': 'normal'},
    });
  }

  Future<void> banMember({
    required String chatId,
    required String userId,
    required String reason,
    DateTime? expiresAt,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('chats').doc(chatId).update({
      'memberStatus.$userId': {
        'status': 'banned',
        'reason': reason,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
        'permanent': expiresAt == null,
      },
    });
  }

  Future<void> unbanMember({
    required String chatId,
    required String userId,
  }) async {
    await _firestore.collection('chats').doc(chatId).update({
      'memberStatus.$userId': {'status': 'normal'},
    });
  }

  Future<void> clearExpiredMemberStatus({
    required String chatId,
    required String userId,
  }) async {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
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

    await _firestore.collection('chats').doc(chatId).update({
      'memberStatus.$userId': {'status': 'normal'},
    });
  }

  Future<List<AppUser>> getAllUsers() async {
    final currentUser = _auth.currentUser;

    final snapshot = await _firestore.collection('users').orderBy('name').get();

    return snapshot.docs
        .map((doc) => AppUser.fromFirestore(doc))
        .where((user) => user.uid != currentUser?.uid)
        .toList();
  }

  Future<List<AppUser>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final users = <AppUser>[];

    for (final uid in userIds) {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        users.add(AppUser.fromFirestore(doc));
      }
    }

    return users;
  }

  Stream<QuerySnapshot> getUserChats() {
    final user = _auth.currentUser;

    if (user == null || user.email == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('chats')
        .where('memberEmails', arrayContains: user.email)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Future<List<AppUser>> searchUsers(String value) async {
    final currentUser = _auth.currentUser;
    final rawText = value.trim();
    final emailText = rawText.toLowerCase();

    if (rawText.isEmpty) return [];

    final results = <String, AppUser>{};

    final emailQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: emailText)
        .limit(5)
        .get();

    for (final doc in emailQuery.docs) {
      final user = AppUser.fromFirestore(doc);

      if (user.uid != currentUser?.uid) {
        results[user.uid] = user;
      }
    }

    final phoneQuery = await _firestore
        .collection('users')
        .where('phone', isEqualTo: rawText)
        .limit(5)
        .get();

    for (final doc in phoneQuery.docs) {
      final user = AppUser.fromFirestore(doc);

      if (user.uid != currentUser?.uid) {
        results[user.uid] = user;
      }
    }

    return results.values.toList();
  }

  Future<AppUser?> findUserByEmailOrPhone(String value) async {
    final users = await searchUsers(value);

    if (users.isEmpty) return null;

    return users.first;
  }

  Future<String> getOrCreatePrivateChat(AppUser otherUser) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Пользователь не авторизован');
    }

    final ids = [currentUser.uid, otherUser.uid]..sort();
    final chatId = ids.join('_');

    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    final chatName = otherUser.name.isNotEmpty
        ? otherUser.name
        : otherUser.email;

    if (!chatDoc.exists) {
      await chatRef.set({
        'name': chatName,
        'type': 'private',
        'memberIds': [currentUser.uid, otherUser.uid],
        'memberEmails': [currentUser.email, otherUser.email],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': null,
        'lastRead': {
          currentUser.uid: FieldValue.serverTimestamp(),
          otherUser.uid: null,
        },
      });
    } else {
      await chatRef.update({'name': chatName});
    }

    return chatId;
  }

  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();

    if (chatData == null) return;

    final chatType = chatData['type'] ?? 'private';
    final isGroup = chatType == 'group';

    if (isGroup) {
      final memberRoles =
          (chatData['memberRoles'] as Map<String, dynamic>?) ?? {};
      final memberStatus =
          (chatData['memberStatus'] as Map<String, dynamic>?) ?? {};

      final role = memberRoles[user.uid] ?? 'member';
      final statusData =
          (memberStatus[user.uid] as Map<String, dynamic>?) ??
          {'status': 'normal'};

      final status = statusData['status'] ?? 'normal';
      final permanent = statusData['permanent'] == true;
      final expiresAt = statusData['expiresAt'];

      final statusIsActive =
          permanent ||
          (expiresAt is Timestamp &&
              expiresAt.toDate().isAfter(DateTime.now()));

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

    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    final senderName = userDoc.data()?['name'] ?? user.email ?? 'Пользователь';

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'text': text,
          'senderId': user.uid,
          'senderEmail': user.email,
          'senderName': senderName,
          'createdAt': FieldValue.serverTimestamp(),
        });

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> markChatAsRead(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('chats').doc(chatId).set({
      'lastRead': {user.uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  Future<int> getUnreadCount(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();

    final data = chatDoc.data();
    if (data == null) return 0;

    final lastReadMap = (data['lastRead'] as Map<String, dynamic>?) ?? {};
    final lastRead = lastReadMap[user.uid];

    Query query = _firestore
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
}
