import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/domain/models/message_content.dart';
import 'package:epistola/domain/models/message_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextMessageContent', () {
    test('normalizes and stores valid text', () {
      final content = TextMessageContent.tryCreate('  Привет, Epistola!  ');

      expect(content, isNotNull);
      expect(content!.type, MessageType.text);
      expect(content.text, 'Привет, Epistola!');
    });

    test('rejects an empty text message', () {
      expect(TextMessageContent.tryCreate('   \n\t   '), isNull);
    });

    test('uses the message text for preview and push', () {
      final content = TextMessageContent.tryCreate('Тестовое сообщение');

      expect(content, isNotNull);
      expect(content!.previewText, 'Тестовое сообщение');
      expect(content.pushText, 'Тестовое сообщение');
    });
  });

  group('ImageMessageContent', () {
    test('accepts complete image metadata', () {
      final metadata = _metadata();

      final content = ImageMessageContent.tryCreate(metadata);

      expect(content, isNotNull);
      expect(content!.type, MessageType.image);
      expect(content.metadata, same(metadata));
    });

    test('rejects incomplete image metadata', () {
      final metadata = _metadata(thumbnailSizeBytes: 0);

      expect(ImageMessageContent.tryCreate(metadata), isNull);
    });

    test('uses a stable representation for preview and push', () {
      final content = ImageMessageContent.tryCreate(_metadata());

      expect(content, isNotNull);
      expect(content!.previewText, ImageMessageContent.representationText);
      expect(content.previewText, 'Фотография');
      expect(content.pushText, 'Фотография');
    });
  });
}

ImageMessageMetadata _metadata({int thumbnailSizeBytes = 24000}) {
  return ImageMessageMetadata(
    thumbnail: MediaAsset(
      id: 'thumb',
      provider: 'firebase',
      path: 'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
      type: ImageMessageMetadata.thumbnailAssetType,
      ownerType: ImageMessageMetadata.messageOwnerType,
      ownerId: 'message-1',
      mimeType: ImageMessageMetadata.supportedMimeType,
      sizeBytes: thumbnailSizeBytes,
      width: 320,
      height: 180,
      version: 3,
    ),
    full: const MediaAsset(
      id: 'full',
      provider: 'firebase',
      path: 'chat_media/chat-1/messages/message-1/v3/full.jpg',
      type: ImageMessageMetadata.fullAssetType,
      ownerType: ImageMessageMetadata.messageOwnerType,
      ownerId: 'message-1',
      mimeType: ImageMessageMetadata.supportedMimeType,
      sizeBytes: 280000,
      width: 1600,
      height: 900,
      version: 3,
    ),
  );
}
