class MediaPaths {
  static String userAvatarThumbnail({
    required String userId,
    required int version,
  }) {
    return 'user_avatars/$userId/v$version/thumb.jpg';
  }

  static String userAvatarFull({required String userId, required int version}) {
    return 'user_avatars/$userId/v$version/full.jpg';
  }

  // Временная совместимость со старой Media Foundation.
  // Удалим после перехода MediaStorageService на версионные пути.
  static String userAvatar(String userId) {
    return 'user_avatars/$userId/avatar.jpg';
  }

  static String groupAvatar(String chatId) {
    return 'group_avatars/$chatId/avatar.jpg';
  }

  static String chatAttachment({
    required String chatId,
    required String messageId,
    required String fileName,
  }) {
    return 'attachments/$chatId/$messageId/$fileName';
  }

  static String chatPreview({
    required String chatId,
    required String messageId,
    required String fileName,
  }) {
    return 'previews/$chatId/$messageId/$fileName';
  }
}
