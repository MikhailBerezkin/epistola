import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import 'chat_base_service.dart';

class ChatPrivateService extends ChatBaseService {
  Future<String> getOrCreatePrivateChat(AppUser otherUser) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      throw Exception('Пользователь не авторизован');
    }

    final ids = [currentUser.uid, otherUser.uid]..sort();
    final chatId = ids.join('_');

    final chatRef = firestore.collection('chats').doc(chatId);

    final currentUserEmail = currentUser.email;
    final memberEmails = <String>[
      if (currentUserEmail != null && currentUserEmail.isNotEmpty)
        currentUserEmail,
      if (otherUser.email.isNotEmpty) otherUser.email,
    ];

    final chatSnapshot = await chatRef.get();

    if (!chatSnapshot.exists) {
      await chatRef.set({
        'name': 'private_chat',
        'type': 'private',
        'memberIds': [currentUser.uid, otherUser.uid],
        'memberEmails': memberEmails,
        'memberRoles': {currentUser.uid: 'member', otherUser.uid: 'member'},
        'memberStatus': {
          currentUser.uid: {'status': 'normal'},
          otherUser.uid: {'status': 'normal'},
        },
        'groupSettings': {'messagePermission': 'all'},
        'lastRead': {currentUser.uid: FieldValue.serverTimestamp()},
        'isDissolved': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      return chatId;
    }

    await chatRef.update({
      'type': 'private',
      'memberIds': FieldValue.arrayUnion([currentUser.uid, otherUser.uid]),
      'memberEmails': FieldValue.arrayUnion(memberEmails),
      'memberRoles.${currentUser.uid}': 'member',
      'memberRoles.${otherUser.uid}': 'member',
      'memberStatus.${currentUser.uid}.status': 'normal',
      'memberStatus.${otherUser.uid}.status': 'normal',
      'lastRead.${currentUser.uid}': FieldValue.serverTimestamp(),
      'isDissolved': false,
    });

    return chatId;
  }
}
