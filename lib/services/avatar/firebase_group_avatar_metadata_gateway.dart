import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/group_avatar.dart';
import 'group_avatar_metadata_gateway.dart';
import 'group_avatar_metadata_mapper.dart';

final class GroupAvatarMetadataReplacement {
  const GroupAvatarMetadataReplacement({
    required this.previousAvatar,
    required this.metadata,
  });

  final GroupAvatar? previousAvatar;
  final Map<String, dynamic> metadata;
}

GroupAvatarMetadataReplacement prepareGroupAvatarMetadataReplacement({
  required String chatId,
  required Map<String, dynamic> currentData,
  required GroupAvatar candidateAvatar,
}) {
  final normalizedChatId = chatId.trim();

  if (normalizedChatId.isEmpty) {
    throw ArgumentError.value(chatId, 'chatId', 'Chat ID must not be empty.');
  }

  final actualType = currentData['type']?.toString() ?? '';

  if (actualType != 'group') {
    throw GroupAvatarTargetTypeException(
      chatId: normalizedChatId,
      actualType: actualType,
    );
  }

  final activeVersion = _readPositiveVersion(currentData['groupAvatarVersion']);

  requireNewerGroupAvatarVersion(
    candidateVersion: candidateAvatar.version,
    activeVersion: activeVersion,
  );

  final metadata = GroupAvatarMetadataMapper.toMap(
    chatId: normalizedChatId,
    avatar: candidateAvatar,
  );

  final previousAvatar = GroupAvatarMetadataMapper.fromMap(
    data: currentData,
    chatId: normalizedChatId,
  );

  return GroupAvatarMetadataReplacement(
    previousAvatar: previousAvatar,
    metadata: metadata,
  );
}

final class FirebaseGroupAvatarMetadataGateway
    implements GroupAvatarMetadataGateway {
  FirebaseGroupAvatarMetadataGateway({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<GroupAvatar?> replace({
    required String chatId,
    required GroupAvatar avatar,
  }) {
    final normalizedChatId = chatId.trim();

    if (normalizedChatId.isEmpty) {
      throw ArgumentError.value(chatId, 'chatId', 'Chat ID must not be empty.');
    }

    // Проверяем candidate до начала сетевой операции.
    GroupAvatarMetadataMapper.toMap(chatId: normalizedChatId, avatar: avatar);

    final chatReference = _firestore.collection('chats').doc(normalizedChatId);

    return _firestore.runTransaction<GroupAvatar?>((transaction) async {
      final snapshot = await transaction.get(chatReference);
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw GroupAvatarChatNotFoundException(normalizedChatId);
      }

      final replacement = prepareGroupAvatarMetadataReplacement(
        chatId: normalizedChatId,
        currentData: data,
        candidateAvatar: avatar,
      );

      transaction.update(chatReference, replacement.metadata);

      return replacement.previousAvatar;
    });
  }
}

int _readPositiveVersion(dynamic value) {
  if (value is! num) {
    return 0;
  }

  final version = value.toInt();

  return version > 0 ? version : 0;
}
