import '../media/media_paths.dart';

final class ImageMessageRemoteCleanupPlan {
  const ImageMessageRemoteCleanupPlan._({
    required this.chatId,
    required this.messageId,
    required this.version,
    required this.thumbnailStoragePath,
    required this.fullStoragePath,
  });

  final String chatId;
  final String messageId;
  final int version;

  final String thumbnailStoragePath;
  final String fullStoragePath;

  static ImageMessageRemoteCleanupPlan? tryCreate({
    required String chatId,
    required String messageId,
    required int version,
  }) {
    final normalizedChatId = chatId.trim();
    final normalizedMessageId = messageId.trim();

    if (normalizedChatId.isEmpty ||
        normalizedMessageId.isEmpty ||
        version <= 0) {
      return null;
    }

    return ImageMessageRemoteCleanupPlan._(
      chatId: normalizedChatId,
      messageId: normalizedMessageId,
      version: version,
      thumbnailStoragePath: MediaPaths.chatMessageImageThumbnail(
        chatId: normalizedChatId,
        messageId: normalizedMessageId,
        version: version,
      ),
      fullStoragePath: MediaPaths.chatMessageImageFull(
        chatId: normalizedChatId,
        messageId: normalizedMessageId,
        version: version,
      ),
    );
  }

  List<String> get storagePaths {
    return List.unmodifiable([thumbnailStoragePath, fullStoragePath]);
  }

  bool ownsStoragePath(String path) {
    return path == thumbnailStoragePath || path == fullStoragePath;
  }
}
