import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_base_service.dart';

class ChatPermissionsService extends ChatBaseService {
  Future<void> updateGroupMessagePermission({
    required String chatId,
    required String permission,
  }) async {
    await firestore.collection('chats').doc(chatId).set({
      'groupSettings': {'messagePermission': permission},
    }, SetOptions(merge: true));
  }

  Future<void> muteMember({
    required String chatId,
    required String userId,
    required String reason,
    DateTime? expiresAt,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    await firestore.collection('chats').doc(chatId).update({
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
    await firestore.collection('chats').doc(chatId).update({
      'memberStatus.$userId': {'status': 'normal'},
    });
  }

  Future<void> banMember({
    required String chatId,
    required String userId,
    required String reason,
    DateTime? expiresAt,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    await firestore.collection('chats').doc(chatId).update({
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
    await firestore.collection('chats').doc(chatId).update({
      'memberStatus.$userId': {'status': 'normal'},
    });
  }

  Future<void> clearExpiredMemberStatus({
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
