import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        .where('memberIds', arrayContains: user?.uid)
        .snapshots();
  }
}
