import '../../domain/models/user_avatar.dart';

abstract interface class UserAvatarMetadataGateway {
  Future<UserAvatar?> replace({
    required String uid,
    required UserAvatar avatar,
  });
}

final class AvatarVersionConflictException implements Exception {
  const AvatarVersionConflictException({
    required this.candidateVersion,
    required this.activeVersion,
  });

  final int candidateVersion;
  final int activeVersion;

  @override
  String toString() {
    return 'AvatarVersionConflictException: candidate version '
        '$candidateVersion does not supersede active version $activeVersion.';
  }
}

void requireNewerAvatarVersion({
  required int candidateVersion,
  required int activeVersion,
}) {
  if (candidateVersion <= activeVersion) {
    throw AvatarVersionConflictException(
      candidateVersion: candidateVersion,
      activeVersion: activeVersion,
    );
  }
}
