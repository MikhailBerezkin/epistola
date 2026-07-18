import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/value_objects/message_text.dart';
import '../../models/app_user.dart';
import 'chat_base_service.dart';

class ChatPrivateService extends ChatBaseService {
  String getPrivateChatId(AppUser otherUser) {
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      throw StateError('Пользователь не авторизован');
    }

    if (otherUser.uid.isEmpty || otherUser.uid == currentUser.uid) {
      throw ArgumentError('Некорректный участник личного чата');
    }

    final ids = [currentUser.uid, otherUser.uid]..sort();

    return ids.join('_');
  }

  Future<bool> privateChatExists(String chatId) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return false;

    final snapshot = await firestore.collection('chats').doc(chatId).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return false;
    }

    final memberIds = List<String>.from(data['memberIds'] ?? const <String>[]);

    return data['type'] == 'private' && memberIds.contains(currentUser.uid);
  }

  Future<String> createPrivateChatWithFirstMessage({
    required AppUser otherUser,
    required String text,
  }) async {
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      throw StateError('Пользователь не авторизован');
    }

    final message = MessageText.tryParse(text);

    if (message == null) {
      throw ArgumentError('Некорректный текст сообщения');
    }

    final senderEmail = currentUser.email;

    if (senderEmail == null || senderEmail.isEmpty) {
      throw StateError('У пользователя отсутствует email');
    }

    final chatId = getPrivateChatId(otherUser);
    final chatRef = firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final userSnapshot = await firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final senderName = (userSnapshot.data()?['name'] as String?) ?? '';

    final messageData = <String, dynamic>{
      'text': message.value,
      'senderId': currentUser.uid,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);
      final chatData = chatSnapshot.data();

      // Чат мог появиться между открытием черновика
      // и отправкой первого сообщения.
      if (chatSnapshot.exists && chatData != null) {
        final memberIds = List<String>.from(
          chatData['memberIds'] ?? const <String>[],
        );

        final isExpectedPrivateChat =
            chatData['type'] == 'private' &&
            memberIds.contains(currentUser.uid) &&
            memberIds.contains(otherUser.uid);

        if (!isExpectedPrivateChat) {
          throw StateError('Документ личного чата имеет неверную структуру');
        }

        transaction.set(messageRef, messageData);

        transaction.update(chatRef, {
          'lastMessage': message.value,
          'lastMessageAt': FieldValue.serverTimestamp(),
        });

        return;
      }

      final memberEmails = <String>{
        senderEmail,
        if (otherUser.email.isNotEmpty) otherUser.email,
      };

      transaction.set(chatRef, {
        'name': 'private_chat',
        'type': 'private',
        'memberIds': [currentUser.uid, otherUser.uid],
        'memberEmails': memberEmails.toList(),
        'memberRoles': {currentUser.uid: 'member', otherUser.uid: 'member'},
        'memberStatus': {
          currentUser.uid: {'status': 'normal'},
          otherUser.uid: {'status': 'normal'},
        },
        'groupSettings': {'messagePermission': 'all'},
        'lastRead': {currentUser.uid: FieldValue.serverTimestamp()},
        'isDissolved': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': message.value,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'firstMessageId': messageRef.id,
      });

      transaction.set(messageRef, messageData);
    });

    return chatId;
  }
}
