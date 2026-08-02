import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageMessageMetadata', () {
    test('accepts a complete thumbnail and full image pair', () {
      final metadata = _metadata();

      expect(metadata.version, 3);
      expect(metadata.provider, 'firebase');
      expect(metadata.messageId, 'message-1');
      expect(metadata.isComplete, isTrue);
      expect(metadata.hasPersistableMetadata, isTrue);
    });

    test('requires both variants to belong to the same message', () {
      final metadata = _metadata(
        thumbnail: _asset(
          id: 'thumb',
          path: 'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
          type: ImageMessageMetadata.thumbnailAssetType,
          ownerId: 'another-message',
          width: 320,
          height: 180,
          sizeBytes: 24000,
        ),
      );

      expect(metadata.isComplete, isFalse);
      expect(metadata.hasPersistableMetadata, isFalse);
    });

    test('requires the same provider and version', () {
      final wrongProvider = _metadata(
        thumbnail: _asset(
          id: 'thumb',
          path: 'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
          type: ImageMessageMetadata.thumbnailAssetType,
          provider: 'another-provider',
          width: 320,
          height: 180,
          sizeBytes: 24000,
        ),
      );

      final wrongVersion = _metadata(
        thumbnail: _asset(
          id: 'thumb',
          path: 'chat_media/chat-1/messages/message-1/v2/thumb.jpg',
          type: ImageMessageMetadata.thumbnailAssetType,
          version: 2,
          width: 320,
          height: 180,
          sizeBytes: 24000,
        ),
      );

      expect(wrongProvider.isComplete, isFalse);
      expect(wrongVersion.isComplete, isFalse);
    });

    test('requires JPEG thumbnail and full variants', () {
      final metadata = _metadata(
        full: _asset(
          id: 'full',
          path: 'chat_media/chat-1/messages/message-1/v3/full.jpg',
          type: ImageMessageMetadata.fullAssetType,
          mimeType: 'image/png',
          width: 1600,
          height: 900,
          sizeBytes: 280000,
        ),
      );

      expect(metadata.isComplete, isFalse);
      expect(metadata.hasPersistableMetadata, isFalse);
    });

    test('requires positive sizes and dimensions', () {
      final metadata = _metadata(
        thumbnail: _asset(
          id: 'thumb',
          path: 'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
          type: ImageMessageMetadata.thumbnailAssetType,
          width: 0,
          height: 180,
          sizeBytes: 0,
        ),
      );

      expect(metadata.isComplete, isTrue);
      expect(metadata.hasPersistableMetadata, isFalse);
    });

    test('requires full dimensions not smaller than thumbnail', () {
      final metadata = _metadata(
        full: _asset(
          id: 'full',
          path: 'chat_media/chat-1/messages/message-1/v3/full.jpg',
          type: ImageMessageMetadata.fullAssetType,
          width: 200,
          height: 100,
          sizeBytes: 280000,
        ),
      );

      expect(metadata.isComplete, isTrue);
      expect(metadata.hasPersistableMetadata, isFalse);
    });

    test('builds cache keys from storage path and version', () {
      final metadata = _metadata();

      expect(
        metadata.thumbnailCacheKey,
        'chat_media/chat-1/messages/message-1/v3/thumb.jpg@3',
      );
      expect(
        metadata.fullCacheKey,
        'chat_media/chat-1/messages/message-1/v3/full.jpg@3',
      );
    });
  });
}

ImageMessageMetadata _metadata({MediaAsset? thumbnail, MediaAsset? full}) {
  return ImageMessageMetadata(
    thumbnail:
        thumbnail ??
        _asset(
          id: 'thumb',
          path: 'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
          type: ImageMessageMetadata.thumbnailAssetType,
          width: 320,
          height: 180,
          sizeBytes: 24000,
        ),
    full:
        full ??
        _asset(
          id: 'full',
          path: 'chat_media/chat-1/messages/message-1/v3/full.jpg',
          type: ImageMessageMetadata.fullAssetType,
          width: 1600,
          height: 900,
          sizeBytes: 280000,
        ),
  );
}

MediaAsset _asset({
  required String id,
  required String path,
  required String type,
  required int width,
  required int height,
  required int sizeBytes,
  String provider = 'firebase',
  String ownerId = 'message-1',
  String mimeType = ImageMessageMetadata.supportedMimeType,
  int version = 3,
}) {
  return MediaAsset(
    id: id,
    provider: provider,
    path: path,
    type: type,
    ownerType: ImageMessageMetadata.messageOwnerType,
    ownerId: ownerId,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    width: width,
    height: height,
    version: version,
  );
}
