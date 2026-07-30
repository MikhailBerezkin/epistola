import 'image_message_limits.dart';
import 'media_asset.dart';

final class ImageMessageMetadata {
  static const String messageOwnerType = 'message';
  static const String thumbnailAssetType = 'imageMessageThumbnail';
  static const String fullAssetType = 'imageMessageFull';

  static const String supportedProvider = 'firebase';
  static const String supportedMimeType = 'image/jpeg';

  const ImageMessageMetadata({required this.thumbnail, required this.full});

  final MediaAsset thumbnail;
  final MediaAsset full;

  int get version => full.version;

  String get provider => full.provider;

  String? get messageId => full.ownerId;

  String get thumbnailStoragePath => thumbnail.path;

  String get fullStoragePath => full.path;

  int? get thumbnailSizeBytes => thumbnail.sizeBytes;

  int? get fullSizeBytes => full.sizeBytes;

  int? get thumbnailWidth => thumbnail.width;

  int? get thumbnailHeight => thumbnail.height;

  int? get fullWidth => full.width;

  int? get fullHeight => full.height;

  bool get hasThumbnail {
    return thumbnailStoragePath.trim().isNotEmpty;
  }

  bool get hasFullImage {
    return fullStoragePath.trim().isNotEmpty;
  }

  bool get isComplete {
    final normalizedMessageId = messageId?.trim();

    return version > 0 &&
        provider.trim().isNotEmpty &&
        normalizedMessageId != null &&
        normalizedMessageId.isNotEmpty &&
        thumbnail.version == version &&
        thumbnail.provider == provider &&
        thumbnail.ownerType == messageOwnerType &&
        full.ownerType == messageOwnerType &&
        thumbnail.ownerId == full.ownerId &&
        thumbnail.type == thumbnailAssetType &&
        full.type == fullAssetType &&
        thumbnail.mimeType == supportedMimeType &&
        full.mimeType == supportedMimeType &&
        hasThumbnail &&
        hasFullImage &&
        thumbnailStoragePath != fullStoragePath;
  }

  bool get hasPersistableMetadata {
    final thumbnailSize = thumbnailSizeBytes;
    final fullSize = fullSizeBytes;
    final thumbnailImageWidth = thumbnailWidth;
    final thumbnailImageHeight = thumbnailHeight;
    final fullImageWidth = fullWidth;
    final fullImageHeight = fullHeight;

    if (!isComplete ||
        provider != supportedProvider ||
        thumbnailSize == null ||
        fullSize == null ||
        thumbnailImageWidth == null ||
        thumbnailImageHeight == null ||
        fullImageWidth == null ||
        fullImageHeight == null) {
      return false;
    }

    final hasValidSizes =
        thumbnailSize > 0 &&
        thumbnailSize <= ImageMessageLimits.maxThumbnailSizeBytes &&
        fullSize > 0 &&
        fullSize <= ImageMessageLimits.maxFullSizeBytes;

    final hasValidThumbnailDimensions =
        thumbnailImageWidth > 0 &&
        thumbnailImageWidth <= ImageMessageLimits.maxThumbnailDimension &&
        thumbnailImageHeight > 0 &&
        thumbnailImageHeight <= ImageMessageLimits.maxThumbnailDimension;

    final hasValidFullDimensions =
        fullImageWidth >= thumbnailImageWidth &&
        fullImageWidth <= ImageMessageLimits.maxFullDimension &&
        fullImageHeight >= thumbnailImageHeight &&
        fullImageHeight <= ImageMessageLimits.maxFullDimension;

    return hasValidSizes &&
        hasValidThumbnailDimensions &&
        hasValidFullDimensions &&
        _hasMatchingAspectRatio(
          thumbnailWidth: thumbnailImageWidth,
          thumbnailHeight: thumbnailImageHeight,
          fullWidth: fullImageWidth,
          fullHeight: fullImageHeight,
        );
  }

  String get thumbnailCacheKey {
    return '$thumbnailStoragePath@$version';
  }

  String get fullCacheKey {
    return '$fullStoragePath@$version';
  }

  static bool _hasMatchingAspectRatio({
    required int thumbnailWidth,
    required int thumbnailHeight,
    required int fullWidth,
    required int fullHeight,
  }) {
    final thumbnailAspectRatio = thumbnailWidth / thumbnailHeight;

    final fullAspectRatio = fullWidth / fullHeight;

    final difference = (thumbnailAspectRatio - fullAspectRatio).abs();

    return difference <= ImageMessageLimits.maxAspectRatioDifference;
  }
}
