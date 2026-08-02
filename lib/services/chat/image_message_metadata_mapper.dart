import '../../domain/models/image_message_metadata.dart';
import '../../domain/models/media_asset.dart';
import '../media/media_paths.dart';

final class ImageMessageMetadataMapper {
  static const fieldNames = <String>{
    'provider',
    'thumbStoragePath',
    'fullStoragePath',
    'thumbSizeBytes',
    'fullSizeBytes',
    'thumbWidth',
    'thumbHeight',
    'fullWidth',
    'fullHeight',
    'mimeType',
    'version',
  };

  static ImageMessageMetadata? fromMap({
    required Map<String, dynamic> data,
    required String chatId,
    required String messageId,
  }) {
    final normalizedChatId = chatId.trim();
    final normalizedMessageId = messageId.trim();

    if (normalizedChatId.isEmpty || normalizedMessageId.isEmpty) {
      return null;
    }

    final keys = data.keys.toSet();

    if (keys.length != fieldNames.length || !keys.containsAll(fieldNames)) {
      return null;
    }

    final provider = _readString(data['provider']);
    final thumbnailPath = _readString(data['thumbStoragePath']);
    final fullPath = _readString(data['fullStoragePath']);
    final thumbnailSize = _readPositiveInt(data['thumbSizeBytes']);
    final fullSize = _readPositiveInt(data['fullSizeBytes']);
    final thumbnailWidth = _readPositiveInt(data['thumbWidth']);
    final thumbnailHeight = _readPositiveInt(data['thumbHeight']);
    final fullWidth = _readPositiveInt(data['fullWidth']);
    final fullHeight = _readPositiveInt(data['fullHeight']);
    final mimeType = _readString(data['mimeType']);
    final version = _readPositiveInt(data['version']);

    if (provider.isEmpty ||
        thumbnailSize == null ||
        fullSize == null ||
        thumbnailWidth == null ||
        thumbnailHeight == null ||
        fullWidth == null ||
        fullHeight == null ||
        version == null ||
        mimeType != ImageMessageMetadata.supportedMimeType) {
      return null;
    }

    final expectedThumbnailPath = MediaPaths.chatMessageImageThumbnail(
      chatId: normalizedChatId,
      messageId: normalizedMessageId,
      version: version,
    );

    final expectedFullPath = MediaPaths.chatMessageImageFull(
      chatId: normalizedChatId,
      messageId: normalizedMessageId,
      version: version,
    );

    if (thumbnailPath != expectedThumbnailPath ||
        fullPath != expectedFullPath) {
      return null;
    }

    final metadata = ImageMessageMetadata(
      thumbnail: MediaAsset(
        id: 'image-message-$normalizedMessageId-v$version-thumb',
        provider: provider,
        path: thumbnailPath,
        type: ImageMessageMetadata.thumbnailAssetType,
        ownerType: ImageMessageMetadata.messageOwnerType,
        ownerId: normalizedMessageId,
        mimeType: mimeType,
        sizeBytes: thumbnailSize,
        width: thumbnailWidth,
        height: thumbnailHeight,
        version: version,
      ),
      full: MediaAsset(
        id: 'image-message-$normalizedMessageId-v$version-full',
        provider: provider,
        path: fullPath,
        type: ImageMessageMetadata.fullAssetType,
        ownerType: ImageMessageMetadata.messageOwnerType,
        ownerId: normalizedMessageId,
        mimeType: mimeType,
        sizeBytes: fullSize,
        width: fullWidth,
        height: fullHeight,
        version: version,
      ),
    );

    return metadata.hasPersistableMetadata ? metadata : null;
  }

  static Map<String, dynamic> toMap({
    required String chatId,
    required String messageId,
    required ImageMessageMetadata metadata,
  }) {
    final normalizedChatId = chatId.trim();
    final normalizedMessageId = messageId.trim();

    if (normalizedChatId.isEmpty) {
      throw ArgumentError.value(chatId, 'chatId', 'Chat ID must not be empty.');
    }

    if (normalizedMessageId.isEmpty) {
      throw ArgumentError.value(
        messageId,
        'messageId',
        'Message ID must not be empty.',
      );
    }

    if (!metadata.hasPersistableMetadata) {
      throw ArgumentError.value(
        metadata,
        'metadata',
        'Image message metadata must be complete.',
      );
    }

    final expectedThumbnailPath = MediaPaths.chatMessageImageThumbnail(
      chatId: normalizedChatId,
      messageId: normalizedMessageId,
      version: metadata.version,
    );

    final expectedFullPath = MediaPaths.chatMessageImageFull(
      chatId: normalizedChatId,
      messageId: normalizedMessageId,
      version: metadata.version,
    );

    final ownsMessage =
        metadata.thumbnail.ownerType == ImageMessageMetadata.messageOwnerType &&
        metadata.full.ownerType == ImageMessageMetadata.messageOwnerType &&
        metadata.thumbnail.ownerId == normalizedMessageId &&
        metadata.full.ownerId == normalizedMessageId;

    final usesExpectedPaths =
        metadata.thumbnailStoragePath == expectedThumbnailPath &&
        metadata.fullStoragePath == expectedFullPath;

    if (!ownsMessage || !usesExpectedPaths) {
      throw ArgumentError.value(
        metadata,
        'metadata',
        'Image metadata must belong to the target message.',
      );
    }

    return {
      'provider': metadata.provider,
      'thumbStoragePath': metadata.thumbnailStoragePath,
      'fullStoragePath': metadata.fullStoragePath,
      'thumbSizeBytes': metadata.thumbnailSizeBytes,
      'fullSizeBytes': metadata.fullSizeBytes,
      'thumbWidth': metadata.thumbnailWidth,
      'thumbHeight': metadata.thumbnailHeight,
      'fullWidth': metadata.fullWidth,
      'fullHeight': metadata.fullHeight,
      'mimeType': ImageMessageMetadata.supportedMimeType,
      'version': metadata.version,
    };
  }

  static String _readString(Object? value) {
    return value is String ? value.trim() : '';
  }

  static int? _readPositiveInt(Object? value) {
    return value is int && value > 0 ? value : null;
  }
}
