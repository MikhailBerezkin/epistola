import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'chat/chat_messages_service.dart';
import 'chat/chat_groups_service.dart';
import 'chat/chat_members_service.dart';
import 'chat/chat_permissions_service.dart';
import 'chat/chat_private_service.dart';
import 'chat/chat_search_service.dart';

class ChatService {
  final ChatMessagesService messages = ChatMessagesService();
  final ChatPrivateService private = ChatPrivateService();
  final ChatGroupsService groups = ChatGroupsService();
  final ChatMembersService members = ChatMembersService();
  final ChatPermissionsService permissions = ChatPermissionsService();
  final ChatSearchService search = ChatSearchService();

  Future<String?> createGroupChat(
    String name, {
    List<AppUser> members = const [],
  }) {
    return groups.createGroupChat(name, members: members);
  }

  Future<void> leaveGroup(String chatId) {
    return groups.leaveGroup(chatId);
  }

  Future<int> getAdminCount(String chatId) {
    return groups.getAdminCount(chatId);
  }

  Future<bool> isLastAdmin(String chatId) {
    return groups.isLastAdmin(chatId);
  }

  Future<void> transferAdminRights({
    required String chatId,
    required String newAdminId,
    bool demoteCurrentAdmin = true,
  }) {
    return groups.transferAdminRights(
      chatId: chatId,
      newAdminId: newAdminId,
      demoteCurrentAdmin: demoteCurrentAdmin,
    );
  }

  Future<bool> leaveGroupSafely(String chatId) {
    return groups.leaveGroupSafely(chatId);
  }

  Future<void> dissolveGroup(String chatId) {
    return groups.dissolveGroup(chatId);
  }

  Future<void> updateGroupMessagePermission({
    required String chatId,
    required String permission,
  }) {
    return permissions.updateGroupMessagePermission(
      chatId: chatId,
      permission: permission,
    );
  }

  Future<void> muteMember({
    required String chatId,
    required String userId,
    required String reason,
    DateTime? expiresAt,
  }) {
    return permissions.muteMember(
      chatId: chatId,
      userId: userId,
      reason: reason,
      expiresAt: expiresAt,
    );
  }

  Future<void> unmuteMember({required String chatId, required String userId}) {
    return permissions.unmuteMember(chatId: chatId, userId: userId);
  }

  Future<void> banMember({
    required String chatId,
    required String userId,
    required String reason,
    DateTime? expiresAt,
  }) {
    return permissions.banMember(
      chatId: chatId,
      userId: userId,
      reason: reason,
      expiresAt: expiresAt,
    );
  }

  Future<void> unbanMember({required String chatId, required String userId}) {
    return permissions.unbanMember(chatId: chatId, userId: userId);
  }

  Future<void> clearExpiredMemberStatus({
    required String chatId,
    required String userId,
  }) {
    return permissions.clearExpiredMemberStatus(chatId: chatId, userId: userId);
  }

  Future<List<AppUser>> getUsersNotInGroup(String chatId) {
    return members.getUsersNotInGroup(chatId);
  }

  Future<void> addMembersToGroup({
    required String chatId,
    required List<AppUser> members,
  }) {
    return this.members.addMembersToGroup(chatId: chatId, members: members);
  }

  Future<List<AppUser>> getUsersByIds(List<String> userIds) {
    return members.getUsersByIds(userIds);
  }

  Future<void> updateMemberRole({
    required String chatId,
    required String userId,
    required String role,
  }) {
    return members.updateMemberRole(chatId: chatId, userId: userId, role: role);
  }

  Future<List<AppUser>> getAllUsers() {
    return search.getAllUsers();
  }

  Stream<QuerySnapshot> getUserChats() {
    return search.getUserChats();
  }

  Future<List<AppUser>> searchUsers(String value) {
    return search.searchUsers(value);
  }

  Future<AppUser?> findUserByEmailOrPhone(String value) {
    return search.findUserByEmailOrPhone(value);
  }

  String getPrivateChatId(AppUser otherUser) {
    return private.getPrivateChatId(otherUser);
  }

  Future<bool> privateChatExists(String chatId) {
    return private.privateChatExists(chatId);
  }

  Future<String> createPrivateChatWithFirstMessage({
    required AppUser otherUser,
    required String text,
  }) {
    return private.createPrivateChatWithFirstMessage(
      otherUser: otherUser,
      text: text,
    );
  }

  Future<void> sendMessage({required String chatId, required String text}) {
    return messages.sendMessage(chatId: chatId, text: text);
  }

  Stream<QuerySnapshot> getMessages(String chatId) {
    return messages.getMessages(chatId);
  }

  Future<void> markChatAsRead(String chatId) {
    return messages.markChatAsRead(chatId);
  }

  Future<int> getUnreadCount(String chatId) {
    return messages.getUnreadCount(chatId);
  }
}
