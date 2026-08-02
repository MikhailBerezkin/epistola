import 'dart:io';

import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/chat/existing_image_message_send_service.dart';
import 'package:epistola/services/chat/existing_image_message_write_service.dart';
import 'package:epistola/services/chat/image_message_remote_cleanup_service.dart';
import 'package:epistola/services/media/image_message_image_processor.dart';
import 'package:epistola/services/media/image_message_storage_gateway.dart';
import 'package:epistola/services/media/image_message_upload_service.dart';
import 'package:epistola/services/media/media_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExistingImageMessageSendService', () {
    late Directory testDirectory;
    late File sourceFile;

    setUp(() async {
      testDirectory = await Directory.systemTemp.createTemp(
        'epistola_existing_image_send_test_',
      );

      sourceFile = File(
        '${testDirectory.path}'
        '${Platform.pathSeparator}'
        'source.jpg',
      );

      await sourceFile.writeAsBytes(List<int>.filled(32, 1), flush: true);
    });

    tearDown(() async {
      if (await testDirectory.exists()) {
        await testDirectory.delete(recursive: true);
      }
    });

    test('uploads and writes an image message to an existing chat', () async {
      final preparedImages = await _prepareImages(sourceFile);

      final storage = _FakeImageMessageStorageGateway();

      final committedMessages = <_CommittedMessage>[];

      final writer = _createWriter(
        messageId: 'message-1',
        onCommit:
            ({
              required String chatId,
              required String messageId,
              required Map<String, dynamic> messageData,
              required String previewText,
              required Object lastMessageAt,
            }) async {
              committedMessages.add(
                _CommittedMessage(
                  chatId: chatId,
                  messageId: messageId,
                  messageData: messageData,
                  previewText: previewText,
                  lastMessageAt: lastMessageAt,
                ),
              );
            },
      );

      final service = _createService(writer: writer, storage: storage);

      final result = await service.sendPreparedImage(
        preparedImages: preparedImages,
        uploaderId: 'user-1',
        chatId: 'chat-1',
        version: 2,
      );

      expect(result.messageId, 'message-1');
      expect(result.metadata.version, 2);
      expect(result.metadata.hasPersistableMetadata, isTrue);

      expect(storage.uploadedVariants, [
        _UploadedVariant.thumbnail,
        _UploadedVariant.full,
      ]);

      expect(storage.deleteAttempts, isEmpty);

      expect(committedMessages, hasLength(1));

      final committed = committedMessages.single;

      expect(committed.chatId, 'chat-1');
      expect(committed.messageId, 'message-1');
      expect(committed.previewText, 'Фотография');

      expect(committed.messageData['messageType'], 'image');

      expect(committed.messageData['text'], '');

      expect(committed.messageData['senderId'], 'user-1');

      expect(committed.messageData['senderEmail'], 'user@example.com');

      expect(committed.messageData['senderName'], 'Пользователь');

      final imageData = committed.messageData['image'] as Map<String, dynamic>;

      expect(
        imageData['thumbStoragePath'],
        'chat_media/chat-1/'
        'messages/message-1/v2/thumb.jpg',
      );

      expect(
        imageData['fullStoragePath'],
        'chat_media/chat-1/'
        'messages/message-1/v2/full.jpg',
      );

      expect(await preparedImages.thumbnailFile.exists(), isFalse);

      expect(await preparedImages.fullFile.exists(), isFalse);

      expect(await sourceFile.exists(), isTrue);
    });

    test('rolls back uploaded files after a confirmed write failure', () async {
      final preparedImages = await _prepareImages(sourceFile);

      final storage = _FakeImageMessageStorageGateway();

      final writer = _createWriter(
        messageId: 'message-2',
        onCommit:
            ({
              required String chatId,
              required String messageId,
              required Map<String, dynamic> messageData,
              required String previewText,
              required Object lastMessageAt,
            }) async {
              throw StateError('Firestore write rejected.');
            },
      );

      final service = _createService(writer: writer, storage: storage);

      final result = service.sendPreparedImage(
        preparedImages: preparedImages,
        uploaderId: 'user-1',
        chatId: 'chat-1',
        version: 1,
      );

      await expectLater(
        result,
        throwsA(
          isA<ExistingImageMessageSendException>()
              .having((error) => error.cause, 'cause', isA<StateError>())
              .having(
                (error) => error.rollbackAttempted,
                'rollbackAttempted',
                isTrue,
              )
              .having(
                (error) => error.rollbackCompleted,
                'rollbackCompleted',
                isTrue,
              )
              .having(
                (error) => error.rollbackDeferred,
                'rollbackDeferred',
                isFalse,
              )
              .having(
                (error) => error.requiresReconciliation,
                'requiresReconciliation',
                isFalse,
              ),
        ),
      );

      expect(storage.uploadedVariants, [
        _UploadedVariant.thumbnail,
        _UploadedVariant.full,
      ]);

      expect(storage.deleteAttempts, [
        'chat_media/chat-1/'
            'messages/message-2/v1/thumb.jpg',
        'chat_media/chat-1/'
            'messages/message-2/v1/full.jpg',
      ]);

      expect(storage.deletedPaths, storage.deleteAttempts);

      expect(await preparedImages.thumbnailFile.exists(), isFalse);

      expect(await preparedImages.fullFile.exists(), isFalse);

      expect(await sourceFile.exists(), isTrue);
    });

    test('defers cleanup when the write result is uncertain', () async {
      final preparedImages = await _prepareImages(sourceFile);

      final storage = _FakeImageMessageStorageGateway();

      final writer = _createWriter(
        messageId: 'message-3',
        onCommit:
            ({
              required String chatId,
              required String messageId,
              required Map<String, dynamic> messageData,
              required String previewText,
              required Object lastMessageAt,
            }) async {
              throw StateError('The write result is uncertain.');
            },
      );

      final service = _createService(
        writer: writer,
        storage: storage,
        rollbackPolicy: (_) => false,
      );

      final result = service.sendPreparedImage(
        preparedImages: preparedImages,
        uploaderId: 'user-1',
        chatId: 'chat-1',
        version: 4,
      );

      await expectLater(
        result,
        throwsA(
          isA<ExistingImageMessageSendException>()
              .having((error) => error.cause, 'cause', isA<StateError>())
              .having(
                (error) => error.rollbackAttempted,
                'rollbackAttempted',
                isFalse,
              )
              .having(
                (error) => error.rollbackCompleted,
                'rollbackCompleted',
                isFalse,
              )
              .having(
                (error) => error.rollbackDeferred,
                'rollbackDeferred',
                isTrue,
              )
              .having(
                (error) => error.requiresReconciliation,
                'requiresReconciliation',
                isTrue,
              ),
        ),
      );

      expect(storage.uploadedVariants, [
        _UploadedVariant.thumbnail,
        _UploadedVariant.full,
      ]);

      expect(storage.deleteAttempts, isEmpty);
      expect(storage.deletedPaths, isEmpty);

      expect(await preparedImages.thumbnailFile.exists(), isFalse);

      expect(await preparedImages.fullFile.exists(), isFalse);

      expect(await sourceFile.exists(), isTrue);
    });
  });
}

ExistingImageMessageSendService _createService({
  required ExistingImageMessageWriteService writer,
  required _FakeImageMessageStorageGateway storage,
  ExistingImageMessageWriteRollbackPolicy? rollbackPolicy,
}) {
  final uploadService = ImageMessageUploadService(
    storage: storage,
    createGrant:
        ({
          required String peerId,
          required String chatId,
          required String messageId,
          required String version,
        }) async {},
  );

  final cleanupService = ImageMessageRemoteCleanupService(gateway: storage);

  return ExistingImageMessageSendService(
    writer: writer,
    uploadService: uploadService,
    cleanupService: cleanupService,
    rollbackPolicy: rollbackPolicy,
  );
}

ExistingImageMessageWriteService _createWriter({
  required String messageId,
  required ExistingImageMessageCommitter onCommit,
}) {
  final createdAt = Object();

  return ExistingImageMessageWriteService(
    createMessageId: (_) => messageId,
    loadSender: () async {
      return const ImageMessageSenderIdentity(
        userId: 'user-1',
        email: 'user@example.com',
        name: 'Пользователь',
      );
    },
    createTimestamp: () => createdAt,
    commit: onCommit,
  );
}

Future<PreparedImageMessageImages> _prepareImages(File sourceFile) {
  final dimensionsByPath = <String, ImageMessageImageDimensions>{
    sourceFile.path: const ImageMessageImageDimensions(
      width: 1600,
      height: 1200,
    ),
  };

  final compressor = _FakeImageCompressor(dimensionsByPath);

  final processor = ImageMessageImageProcessor(
    compressor: compressor,
    probe: (path) async {
      final dimensions = dimensionsByPath[path];

      if (dimensions == null) {
        throw StateError('Missing fake dimensions for $path');
      }

      return dimensions;
    },
  );

  return processor.process(sourceFile.path);
}

final class _FakeImageCompressor implements AvatarImageCompressorGateway {
  const _FakeImageCompressor(this.dimensionsByPath);

  final Map<String, ImageMessageImageDimensions> dimensionsByPath;

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    final outputFile = File(request.targetPath);

    final sizeBytes = request.targetPath.contains('thumbnail_')
        ? 24 * 1024
        : 280 * 1024;

    await outputFile.writeAsBytes(List<int>.filled(sizeBytes, 0), flush: true);

    dimensionsByPath[request.targetPath] = ImageMessageImageDimensions(
      width: request.width,
      height: request.height,
    );

    return AvatarCompressedImage(path: request.targetPath);
  }
}

final class _FakeImageMessageStorageGateway
    implements ImageMessageStorageGateway {
  final List<_UploadedVariant> uploadedVariants = [];
  final List<String> deleteAttempts = [];
  final List<String> deletedPaths = [];

  @override
  Future<MediaAsset> uploadThumbnail({
    required File file,
    required String uploaderId,
    required String chatId,
    required String messageId,
    required int version,
    required int width,
    required int height,
    bool usesFirstPrivateImageGrant = false,
  }) async {
    uploadedVariants.add(_UploadedVariant.thumbnail);

    return _createAsset(
      file: file,
      chatId: chatId,
      messageId: messageId,
      version: version,
      width: width,
      height: height,
      variant: _UploadedVariant.thumbnail,
    );
  }

  @override
  Future<MediaAsset> uploadFull({
    required File file,
    required String uploaderId,
    required String chatId,
    required String messageId,
    required int version,
    required int width,
    required int height,
    bool usesFirstPrivateImageGrant = false,
  }) async {
    uploadedVariants.add(_UploadedVariant.full);

    return _createAsset(
      file: file,
      chatId: chatId,
      messageId: messageId,
      version: version,
      width: width,
      height: height,
      variant: _UploadedVariant.full,
    );
  }

  @override
  Future<void> deleteFile(String path) async {
    deleteAttempts.add(path);
    deletedPaths.add(path);
  }

  static MediaAsset _createAsset({
    required File file,
    required String chatId,
    required String messageId,
    required int version,
    required int width,
    required int height,
    required _UploadedVariant variant,
  }) {
    final isThumbnail = variant == _UploadedVariant.thumbnail;

    final path = isThumbnail
        ? MediaPaths.chatMessageImageThumbnail(
            chatId: chatId,
            messageId: messageId,
            version: version,
          )
        : MediaPaths.chatMessageImageFull(
            chatId: chatId,
            messageId: messageId,
            version: version,
          );

    return MediaAsset(
      id: isThumbnail
          ? 'image-message-$messageId-v$version-thumb'
          : 'image-message-$messageId-v$version-full',
      provider: ImageMessageMetadata.supportedProvider,
      path: path,
      type: isThumbnail
          ? ImageMessageMetadata.thumbnailAssetType
          : ImageMessageMetadata.fullAssetType,
      ownerType: ImageMessageMetadata.messageOwnerType,
      ownerId: messageId,
      mimeType: ImageMessageMetadata.supportedMimeType,
      sizeBytes: file.lengthSync(),
      width: width,
      height: height,
      version: version,
    );
  }
}

enum _UploadedVariant { thumbnail, full }

final class _CommittedMessage {
  const _CommittedMessage({
    required this.chatId,
    required this.messageId,
    required this.messageData,
    required this.previewText,
    required this.lastMessageAt,
  });

  final String chatId;
  final String messageId;
  final Map<String, dynamic> messageData;
  final String previewText;
  final Object lastMessageAt;
}
