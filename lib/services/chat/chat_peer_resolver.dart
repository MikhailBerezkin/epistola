import '../../models/app_user.dart';

class ChatPeerResolver {
  const ChatPeerResolver._();

  static String? otherUserId({
    required Map<String, dynamic> chatData,
    required String currentUserId,
  }) {
    final normalizedCurrentUserId = currentUserId.trim();

    if (chatData['type'] != 'private' || normalizedCurrentUserId.isEmpty) {
      return null;
    }

    final rawMemberIds = chatData['memberIds'];

    if (rawMemberIds is! Iterable) {
      return null;
    }

    for (final value in rawMemberIds) {
      if (value is! String) {
        continue;
      }

      final userId = value.trim();

      if (userId.isNotEmpty && userId != normalizedCurrentUserId) {
        return userId;
      }
    }

    return null;
  }

  static Set<String> collectOtherUserIds({
    required Iterable<Map<String, dynamic>> chats,
    required String currentUserId,
  }) {
    final result = <String>{};

    for (final chatData in chats) {
      final userId = otherUserId(
        chatData: chatData,
        currentUserId: currentUserId,
      );

      if (userId != null) {
        result.add(userId);
      }
    }

    return result;
  }

  static AppUser? resolveOtherUser({
    required Map<String, dynamic> chatData,
    required String currentUserId,
    required Map<String, AppUser> usersById,
  }) {
    final userId = otherUserId(
      chatData: chatData,
      currentUserId: currentUserId,
    );

    return userId == null ? null : usersById[userId];
  }
}
