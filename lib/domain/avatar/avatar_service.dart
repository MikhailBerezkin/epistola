import '../models/avatar_upload_request.dart';

abstract class AvatarService {
  /// Загружает новый аватар пользователя.
  Future<void> uploadAvatar({
    required String userId,
    required AvatarUploadRequest request,
  });

  /// Удаляет текущий аватар пользователя.
  Future<void> deleteAvatar({required String userId});
}
