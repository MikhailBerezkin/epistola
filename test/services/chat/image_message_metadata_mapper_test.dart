import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/services/chat/image_message_metadata_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageMessageMetadataMapper', () {
    test('reads valid path-first metadata', () {
      final metadata = ImageMessageMetadataMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: _map(),
      );

      expect(metadata, isNotNull);
      expect(metadata!.provider, 'firebase');
      expect(metadata.version, 3);
      expect(metadata.messageId, 'message-1');
      expect(metadata.hasPersistableMetadata, isTrue);
    });

    test('rejects metadata belonging to another message', () {
      final metadata = ImageMessageMetadataMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: _map(
          thumbnailPath: 'chat_media/chat-1/messages/message-2/v3/thumb.jpg',
          fullPath: 'chat_media/chat-1/messages/message-2/v3/full.jpg',
        ),
      );

      expect(metadata, isNull);
    });

    test('rejects metadata belonging to another chat', () {
      final metadata = ImageMessageMetadataMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: _map(
          thumbnailPath: 'chat_media/chat-2/messages/message-1/v3/thumb.jpg',
          fullPath: 'chat_media/chat-2/messages/message-1/v3/full.jpg',
        ),
      );

      expect(metadata, isNull);
    });

    test('rejects incomplete metadata', () {
      final data = _map()..remove('fullHeight');

      final metadata = ImageMessageMetadataMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: data,
      );

      expect(metadata, isNull);
    });

    test('rejects unexpected metadata fields', () {
      final data = _map()..['downloadUrl'] = 'https://example.com/image.jpg';

      final metadata = ImageMessageMetadataMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: data,
      );

      expect(metadata, isNull);
    });

    test('rejects fractional numeric values', () {
      final data = _map()..['version'] = 3.5;

      final metadata = ImageMessageMetadataMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: data,
      );

      expect(metadata, isNull);
    });

    test('rejects unsupported MIME type', () {
      final metadata = ImageMessageMetadataMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: _map(mimeType: 'image/png'),
      );

      expect(metadata, isNull);
    });

    test('rejects non-positive sizes and dimensions', () {
      final metadata = ImageMessageMetadataMapper.fromMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        data: _map(thumbnailSize: 0),
      );

      expect(metadata, isNull);
    });

    test('writes complete metadata', () {
      final metadata = ImageMessageMetadataMapper.toMap(
        chatId: 'chat-1',
        messageId: 'message-1',
        metadata: _metadata(),
      );

      expect(metadata, _map());
    });

    test('rejects metadata owned by another message when writing', () {
      final metadata = _metadata(ownerId: 'message-2');

      expect(
        () => ImageMessageMetadataMapper.toMap(
          chatId: 'chat-1',
          messageId: 'message-1',
          metadata: metadata,
        ),
        throwsArgumentError,
      );
    });

    test('rejects unexpected storage paths when writing', () {
      final metadata = _metadata(
        thumbnailPath: 'chat_media/chat-2/messages/message-1/v3/thumb.jpg',
        fullPath: 'chat_media/chat-2/messages/message-1/v3/full.jpg',
      );

      expect(
        () => ImageMessageMetadataMapper.toMap(
          chatId: 'chat-1',
          messageId: 'message-1',
          metadata: metadata,
        ),
        throwsArgumentError,
      );
    });
  });
}

Map<String, dynamic> _map({
  String thumbnailPath = 'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
  String fullPath = 'chat_media/chat-1/messages/message-1/v3/full.jpg',
  int thumbnailSize = 24000,
  String mimeType = ImageMessageMetadata.supportedMimeType,
}) {
  return {
    'provider': 'firebase',
    'thumbStoragePath': thumbnailPath,
    'fullStoragePath': fullPath,
    'thumbSizeBytes': thumbnailSize,
    'fullSizeBytes': 280000,
    'thumbWidth': 320,
    'thumbHeight': 180,
    'fullWidth': 1600,
    'fullHeight': 900,
    'mimeType': mimeType,
    'version': 3,
  };
}

ImageMessageMetadata _metadata({
  String ownerId = 'message-1',
  String thumbnailPath = 'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
  String fullPath = 'chat_media/chat-1/messages/message-1/v3/full.jpg',
}) {
  return ImageMessageMetadata(
    thumbnail: _asset(
      id: 'thumb',
      ownerId: ownerId,
      path: thumbnailPath,
      type: ImageMessageMetadata.thumbnailAssetType,
      width: 320,
      height: 180,
      sizeBytes: 24000,
    ),
    full: _asset(
      id: 'full',
      ownerId: ownerId,
      path: fullPath,
      type: ImageMessageMetadata.fullAssetType,
      width: 1600,
      height: 900,
      sizeBytes: 280000,
    ),
  );
}

MediaAsset _asset({
  required String id,
  required String ownerId,
  required String path,
  required String type,
  required int width,
  required int height,
  required int sizeBytes,
}) {
  return MediaAsset(
    id: id,
    provider: 'firebase',
    path: path,
    type: type,
    ownerType: ImageMessageMetadata.messageOwnerType,
    ownerId: ownerId,
    mimeType: ImageMessageMetadata.supportedMimeType,
    sizeBytes: sizeBytes,
    width: width,
    height: height,
    version: 3,
  );
}
