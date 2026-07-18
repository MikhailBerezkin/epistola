import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import 'chat_base_service.dart';

class ChatGroupsService extends ChatBaseService {
  Future<String?> createGroupChat(
    String name, {
    List<AppUser> members = const [],
  }) async {
    final user = auth.currentUser;
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

    final chatRef = await firestore.collection('chats').add({
      'name': name,
      'type': 'group',
      'memberIds': memberIds.toList(),
      'memberEmails': memberEmails.toList(),
      'memberRoles': memberRoles,
      'memberStatus': memberStatus,
      'groupSettings': {'messagePermission': 'all'},
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Группа создана',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastRead': {user.uid: FieldValue.serverTimestamp()},
    });

    return chatRef.id;
  }

  Future<void> leaveGroup(String chatId) async {
    final user = auth.currentUser;
    if (user == null) return;

    await firestore.collection('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayRemove([user.uid]),
      'memberEmails': FieldValue.arrayRemove([
        if (user.email != null) user.email!,
      ]),
      'memberRoles.${user.uid}': FieldValue.delete(),
      'memberStatus.${user.uid}': FieldValue.delete(),
      'lastRead.${user.uid}': FieldValue.delete(),
    });
  }

  Future<int> getAdminCount(String chatId) async {
    final doc = await firestore.collection('chats').doc(chatId).get();

    final data = doc.data();
    if (data == null) return 0;

    final memberRoles = (data['memberRoles'] as Map<String, dynamic>?) ?? {};

    int count = 0;

    for (final role in memberRoles.values) {
      if (role == 'admin' || role == 'owner') {
        count++;
      }
    }

    return count;
  }

  Future<bool> isLastAdmin(String chatId) async {
    final user = auth.currentUser;
    if (user == null) return false;

    final doc = await firestore.collection('chats').doc(chatId).get();

    final data = doc.data();
    if (data == null) return false;

    final memberRoles = (data['memberRoles'] as Map<String, dynamic>?) ?? {};

    final currentRole = memberRoles[user.uid];

    if (currentRole != 'admin' && currentRole != 'owner') {
      return false;
    }

    return await getAdminCount(chatId) == 1;
  }

  Future<void> transferAdminRights({
    required String chatId,
    required String newAdminId,
    bool demoteCurrentAdmin = true,
  }) async {
    final user = auth.currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{
      'memberRoles.$newAdminId': 'admin',
      'lastMessage': 'Права администратора переданы',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageId': FieldValue.delete(),
    };

    if (demoteCurrentAdmin) {
      updates['memberRoles.${user.uid}'] = 'member';
    }

    await firestore.collection('chats').doc(chatId).update(updates);
  }

  Future<bool> leaveGroupSafely(String chatId) async {
    final user = auth.currentUser;
    if (user == null) return false;

    final lastAdmin = await isLastAdmin(chatId);

    if (lastAdmin) {
      return false;
    }

    await leaveGroup(chatId);
    return true;
  }

  Future<void> dissolveGroup(String chatId) async {
    final user = auth.currentUser;
    if (user == null) return;

    final doc = await firestore.collection('chats').doc(chatId).get();
    final data = doc.data();
    if (data == null) return;

    final memberRoles = (data['memberRoles'] as Map<String, dynamic>?) ?? {};

    final currentRole = memberRoles[user.uid];

    if (currentRole != 'admin' && currentRole != 'owner') {
      return;
    }

    await firestore.collection('chats').doc(chatId).update({
      'isDissolved': true,
      'dissolvedBy': user.uid,
      'dissolvedAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Группа распущена',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageId': FieldValue.delete(),

      // Убираем группу из списка чатов у всех участников.
      // История сообщений физически остаётся в Firestore.
      'memberIds': [],
      'memberEmails': [],
    });
  }
}
