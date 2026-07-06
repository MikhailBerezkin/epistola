class MediaPaths {
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
