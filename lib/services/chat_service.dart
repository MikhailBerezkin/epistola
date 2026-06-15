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

    for (final member in members) {
      memberIds.add(member.uid);
      memberEmails.add(member.email);
      memberRoles[member.uid] = 'member';
    }

    final chatRef = await _firestore.collection('chats').add({
      'name': name,
      'type': 'group',
      'memberIds': memberIds.toList(),
      'memberEmails': memberEmails.toList(),
      'memberRoles': memberRoles,
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

    await _firestore.collection('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayUnion(memberIds),
      'memberEmails': FieldValue.arrayUnion(memberEmails),
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
