import 'package:epistola/domain/models/image_message_limits.dart';
import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageMessageLimits', () {
    test('accepts metadata at the configured limits', () {
      final metadata = _metadata(
        thumbnailSizeBytes: ImageMessageLimits.maxThumbnailSizeBytes,
        fullSizeBytes: ImageMessageLimits.maxFullSizeBytes,
        thumbnailWidth: ImageMessageLimits.maxThumbnailDimension,
        thumbnailHeight: 270,
        fullWidth: ImageMessageLimits.maxFullDimension,
        fullHeight: 1080,
      );

      expect(metadata.hasPersistableMetadata, isTrue);
    });

    test('rejects an unsupported provider', () {
      final metadata = _metadata(provider: 'another-provider');

      expect(metadata.isComplete, isTrue);
      expect(metadata.hasPersistableMetadata, isFalse);
    });

    test('rejects an oversized thumbnail', () {
      final metadata = _metadata(
        thumbnailSizeBytes: ImageMessageLimits.maxThumbnailSizeBytes + 1,
      );

      expect(metadata.hasPersistableMetadata, isFalse);
    });

    test('rejects an oversized full image', () {
      final metadata = _metadata(
        fullSizeBytes: ImageMessageLimits.maxFullSizeBytes + 1,
      );

      expect(metadata.hasPersistableMetadata, isFalse);
    });

    test('rejects oversized thumbnail dimensions', () {
      final metadata = _metadata(
        thumbnailWidth: ImageMessageLimits.maxThumbnailDimension + 1,
        thumbnailHeight: 270,
      );

      expect(metadata.hasPersistableMetadata, isFalse);
    });

    test('rejects oversized full dimensions', () {
      final metadata = _metadata(
        fullWidth: ImageMessageLimits.maxFullDimension + 1,
        fullHeight: 1080,
      );

      expect(metadata.hasPersistableMetadata, isFalse);
    });

    test('rejects mismatched thumbnail and full proportions', () {
      final metadata = _metadata(
        thumbnailWidth: 320,
        thumbnailHeight: 180,
        fullWidth: 1600,
        fullHeight: 1000,
      );

      expect(metadata.hasPersistableMetadata, isFalse);
    });

    test('accepts a small aspect ratio rounding difference', () {
      final metadata = _metadata(
        thumbnailWidth: 479,
        thumbnailHeight: 269,
        fullWidth: 1920,
        fullHeight: 1080,
      );

      expect(metadata.hasPersistableMetadata, isTrue);
    });
  });
}

ImageMessageMetadata _metadata({
  String provider = ImageMessageMetadata.supportedProvider,
  int thumbnailSizeBytes = 24000,
  int fullSizeBytes = 280000,
  int thumbnailWidth = 320,
  int thumbnailHeight = 180,
  int fullWidth = 1600,
  int fullHeight = 900,
}) {
  return ImageMessageMetadata(
    thumbnail: MediaAsset(
      id: 'thumb',
      provider: provider,
      path: 'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
      type: ImageMessageMetadata.thumbnailAssetType,
      ownerType: ImageMessageMetadata.messageOwnerType,
      ownerId: 'message-1',
      mimeType: ImageMessageMetadata.supportedMimeType,
      sizeBytes: thumbnailSizeBytes,
      width: thumbnailWidth,
      height: thumbnailHeight,
      version: 3,
    ),
    full: MediaAsset(
      id: 'full',
      provider: provider,
      path: 'chat_media/chat-1/messages/message-1/v3/full.jpg',
      type: ImageMessageMetadata.fullAssetType,
      ownerType: ImageMessageMetadata.messageOwnerType,
      ownerId: 'message-1',
      mimeType: ImageMessageMetadata.supportedMimeType,
      sizeBytes: fullSizeBytes,
      width: fullWidth,
      height: fullHeight,
      version: 3,
    ),
  );
}
