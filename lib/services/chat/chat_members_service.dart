import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import 'chat_base_service.dart';
import 'chat_search_service.dart';

class ChatMembersService extends ChatBaseService {
  final ChatSearchService search = ChatSearchService();

  Future<List<AppUser>> getUsersNotInGroup(String chatId) async {
    final chatDoc = await firestore.collection('chats').doc(chatId).get();
    final data = chatDoc.data();

    if (data == null) return [];

    final memberIds = List<String>.from(data['memberIds'] ?? []);
    final allUsers = await search.getAllUsers();

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

    await firestore.collection('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayUnion(memberIds),
      'memberEmails': FieldValue.arrayUnion(memberEmails),
      ...memberUpdates,
    });
  }

  Future<List<AppUser>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final users = <AppUser>[];

    for (final uid in userIds) {
      final doc = await firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        users.add(AppUser.fromFirestore(doc));
      }
    }

    return users;
  }

  Future<void> updateMemberRole({
    required String chatId,
    required String userId,
    required String role,
  }) async {
    await firestore.collection('chats').doc(chatId).update({
      'memberRoles.$userId': role,
    });
  }
}
