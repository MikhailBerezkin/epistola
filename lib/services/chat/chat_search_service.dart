import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import 'chat_base_service.dart';

class ChatSearchService extends ChatBaseService {
  Future<List<AppUser>> getAllUsers() async {
    final currentUser = auth.currentUser;

    final snapshot = await firestore.collection('users').orderBy('name').get();

    return snapshot.docs
        .map((doc) => AppUser.fromFirestore(doc))
        .where((user) => user.uid != currentUser?.uid)
        .toList();
  }

  Stream<QuerySnapshot> getUserChats() {
    final user = auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return firestore
        .collection('chats')
        .where('memberIds', arrayContains: user.uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Future<List<AppUser>> searchUsers(String value) async {
    final currentUser = auth.currentUser;
    final rawText = value.trim();
    final emailText = rawText.toLowerCase();

    if (rawText.isEmpty) return [];

    final results = <String, AppUser>{};

    final emailQuery = await firestore
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

    final phoneQuery = await firestore
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
}
