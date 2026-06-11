import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createGroupChat(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('chats').add({
      'name': name,
      'type': 'group',
      'memberIds': [user.uid],
      'memberEmails': [user.email],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageAt': null,
    });
  }

  Stream<QuerySnapshot> getUserChats() {
    final user = _auth.currentUser;

    return _firestore
        .collection('chats')
        .where('memberEmails', arrayContains: user?.email)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Future<AppUser?> findUserByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) return null;

    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    return AppUser.fromFirestore(query.docs.first);
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

    if (!chatDoc.exists) {
      await chatRef.set({
        'name': otherUser.name.isNotEmpty ? otherUser.name : otherUser.email,
        'type': 'private',
        'memberIds': [currentUser.uid, otherUser.uid],
        'memberEmails': [currentUser.email, otherUser.email],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': null,
      });
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
}
