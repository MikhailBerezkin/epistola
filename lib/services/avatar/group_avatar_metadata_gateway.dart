import '../../domain/models/group_avatar.dart';

abstract interface class GroupAvatarMetadataGateway {
  Future<GroupAvatar?> replace({
    required String chatId,
    required GroupAvatar avatar,
  });
}

final class GroupAvatarVersionConflictException implements Exception {
  const GroupAvatarVersionConflictException({
    required this.candidateVersion,
    required this.activeVersion,
  });

  final int candidateVersion;
  final int activeVersion;

  @override
  String toString() {
    return 'GroupAvatarVersionConflictException: candidate version '
        '$candidateVersion does not supersede active version $activeVersion.';
  }
}

final class GroupAvatarChatNotFoundException implements Exception {
  const GroupAvatarChatNotFoundException(this.chatId);

  final String chatId;

  @override
  String toString() {
    return 'GroupAvatarChatNotFoundException: chat $chatId was not found.';
  }
}

final class GroupAvatarTargetTypeException implements Exception {
  const GroupAvatarTargetTypeException({
    required this.chatId,
    required this.actualType,
  });

  final String chatId;
  final String actualType;

  @override
  String toString() {
    return 'GroupAvatarTargetTypeException: chat $chatId has type '
        '"$actualType" instead of "group".';
  }
}

void requireNewerGroupAvatarVersion({
  required int candidateVersion,
  required int activeVersion,
}) {
  if (candidateVersion <= activeVersion) {
    throw GroupAvatarVersionConflictException(
      candidateVersion: candidateVersion,
      activeVersion: activeVersion,
    );
  }
}
