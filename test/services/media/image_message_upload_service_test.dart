import 'dart:io';

import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/media/image_message_image_processor.dart';
import 'package:epistola/services/media/image_message_storage_gateway.dart';
import 'package:epistola/services/media/image_message_upload_service.dart';
import 'package:epistola/services/media/media_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageMessageUploadService', () {
    late Directory testDirectory;
    late File sourceFile;

    setUp(() async {
      testDirectory = await Directory.systemTemp.createTemp(
        'epistola_image_message_upload_test_',
      );

      sourceFile = File(
        '${testDirectory.path}${Platform.pathSeparator}source.jpg',
      );

      await sourceFile.writeAsBytes(List<int>.filled(32, 1), flush: true);
    });

    tearDown(() async {
      if (await testDirectory.exists()) {
        await testDirectory.delete(recursive: true);
      }
    });

    test('uploads thumbnail and full image for an existing chat', () async {
      final preparedImages = await _prepareImages(sourceFile);
      final storage = _FakeImageMessageStorageGateway();

      var grantCallCount = 0;

      final service = ImageMessageUploadService(
        storage: storage,
        createGrant:
            ({
              required String peerId,
              required String chatId,
              required String messageId,
              required String version,
            }) async {
              grantCallCount += 1;
            },
      );

      final metadata = await service.uploadPreparedImage(
        preparedImages: preparedImages,
        uploaderId: 'user-1',
        chatId: 'user-1_user-2',
        messageId: 'message-1',
      );

      expect(metadata.hasPersistableMetadata, isTrue);
      expect(metadata.version, 1);

      expect(
        metadata.thumbnailStoragePath,
        'chat_media/user-1_user-2/'
        'messages/message-1/v1/thumb.jpg',
      );

      expect(
        metadata.fullStoragePath,
        'chat_media/user-1_user-2/'
        'messages/message-1/v1/full.jpg',
      );

      expect(storage.uploadRecords.map((record) => record.variant).toList(), [
        _UploadedVariant.thumbnail,
        _UploadedVariant.full,
      ]);

      expect(
        storage.uploadRecords
            .map((record) => record.usesFirstPrivateImageGrant)
            .toList(),
        [false, false],
      );

      expect(grantCallCount, 0);
      expect(storage.deleteAttempts, isEmpty);

      expect(await preparedImages.thumbnailFile.exists(), isFalse);

      expect(await preparedImages.fullFile.exists(), isFalse);

      expect(await sourceFile.exists(), isTrue);
    });

    test('creates a grant before uploading a first private image', () async {
      final preparedImages = await _prepareImages(sourceFile);
      final storage = _FakeImageMessageStorageGateway();
      final grantCalls = <_GrantCall>[];

      final service = ImageMessageUploadService(
        storage: storage,
        createGrant:
            ({
              required String peerId,
              required String chatId,
              required String messageId,
              required String version,
            }) async {
              grantCalls.add(
                _GrantCall(
                  peerId: peerId,
                  chatId: chatId,
                  messageId: messageId,
                  version: version,
                ),
              );

              expect(storage.uploadRecords, isEmpty);
            },
      );

      final metadata = await service.uploadPreparedImage(
        preparedImages: preparedImages,
        uploaderId: 'user-1',
        chatId: 'user-1_user-3',
        messageId: 'first-image-message',
        version: 3,
        firstPrivatePeerId: 'user-3',
      );

      expect(metadata.hasPersistableMetadata, isTrue);
      expect(metadata.version, 3);

      expect(grantCalls, hasLength(1));
      expect(grantCalls.single.peerId, 'user-3');
      expect(grantCalls.single.chatId, 'user-1_user-3');
      expect(grantCalls.single.messageId, 'first-image-message');
      expect(grantCalls.single.version, 'v3');

      expect(storage.uploadRecords, hasLength(2));

      for (final record in storage.uploadRecords) {
        expect(record.usesFirstPrivateImageGrant, isTrue);
      }

      expect(await preparedImages.thumbnailFile.exists(), isFalse);

      expect(await preparedImages.fullFile.exists(), isFalse);
    });

    test('rolls back both canonical paths when full upload fails', () async {
      final preparedImages = await _prepareImages(sourceFile);

      final storage = _FakeImageMessageStorageGateway(failFullUpload: true);

      final service = ImageMessageUploadService(
        storage: storage,
        createGrant:
            ({
              required String peerId,
              required String chatId,
              required String messageId,
              required String version,
            }) async {},
      );

      final result = service.uploadPreparedImage(
        preparedImages: preparedImages,
        uploaderId: 'user-1',
        chatId: 'user-1_user-2',
        messageId: 'message-2',
      );

      await expectLater(
        result,
        throwsA(
          isA<ImageMessageUploadException>()
              .having(
                (error) => error.requiredRemoteRollback,
                'requiredRemoteRollback',
                isTrue,
              )
              .having(
                (error) => error.rollbackCompleted,
                'rollbackCompleted',
                isTrue,
              )
              .having((error) => error.cause, 'cause', isA<StateError>()),
        ),
      );

      expect(storage.uploadRecords, hasLength(2));

      expect(storage.deleteAttempts, [
        'chat_media/user-1_user-2/'
            'messages/message-2/v1/thumb.jpg',
        'chat_media/user-1_user-2/'
            'messages/message-2/v1/full.jpg',
      ]);

      expect(storage.deletedPaths, storage.deleteAttempts);

      expect(await preparedImages.thumbnailFile.exists(), isFalse);

      expect(await preparedImages.fullFile.exists(), isFalse);

      expect(await sourceFile.exists(), isTrue);
    });

    test('does not access Storage when grant creation fails', () async {
      final preparedImages = await _prepareImages(sourceFile);
      final storage = _FakeImageMessageStorageGateway();

      final service = ImageMessageUploadService(
        storage: storage,
        createGrant:
            ({
              required String peerId,
              required String chatId,
              required String messageId,
              required String version,
            }) async {
              throw StateError('Grant creation failed.');
            },
      );

      final result = service.uploadPreparedImage(
        preparedImages: preparedImages,
        uploaderId: 'user-1',
        chatId: 'user-1_user-3',
        messageId: 'first-image-message',
        firstPrivatePeerId: 'user-3',
      );

      await expectLater(
        result,
        throwsA(
          isA<ImageMessageUploadException>()
              .having(
                (error) => error.requiredRemoteRollback,
                'requiredRemoteRollback',
                isFalse,
              )
              .having(
                (error) => error.rollbackCompleted,
                'rollbackCompleted',
                isTrue,
              )
              .having((error) => error.cause, 'cause', isA<StateError>()),
        ),
      );

      expect(storage.uploadRecords, isEmpty);
      expect(storage.deleteAttempts, isEmpty);
      expect(storage.deletedPaths, isEmpty);

      expect(await preparedImages.thumbnailFile.exists(), isFalse);

      expect(await preparedImages.fullFile.exists(), isFalse);
    });

    test('reports paths that could not be removed during rollback', () async {
      final preparedImages = await _prepareImages(sourceFile);

      final fullPath = MediaPaths.chatMessageImageFull(
        chatId: 'user-1_user-2',
        messageId: 'message-3',
        version: 1,
      );

      final storage = _FakeImageMessageStorageGateway(
        failFullUpload: true,
        deleteFailures: {fullPath},
      );

      final service = ImageMessageUploadService(
        storage: storage,
        createGrant:
            ({
              required String peerId,
              required String chatId,
              required String messageId,
              required String version,
            }) async {},
      );

      final result = service.uploadPreparedImage(
        preparedImages: preparedImages,
        uploaderId: 'user-1',
        chatId: 'user-1_user-2',
        messageId: 'message-3',
      );

      await expectLater(
        result,
        throwsA(
          isA<ImageMessageUploadException>()
              .having(
                (error) => error.requiredRemoteRollback,
                'requiredRemoteRollback',
                isTrue,
              )
              .having(
                (error) => error.rollbackCompleted,
                'rollbackCompleted',
                isFalse,
              )
              .having(
                (error) => error.rollbackResult?.failedPaths,
                'failedPaths',
                [fullPath],
              ),
        ),
      );

      expect(storage.deleteAttempts, [
        'chat_media/user-1_user-2/'
            'messages/message-3/v1/thumb.jpg',
        fullPath,
      ]);

      expect(storage.deletedPaths, [
        'chat_media/user-1_user-2/'
            'messages/message-3/v1/thumb.jpg',
      ]);

      expect(await preparedImages.thumbnailFile.exists(), isFalse);

      expect(await preparedImages.fullFile.exists(), isFalse);
    });
  });
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
  _FakeImageMessageStorageGateway({
    this.failFullUpload = false,
    this.deleteFailures = const {},
  });

  final bool failFullUpload;
  final Set<String> deleteFailures;

  final List<_UploadRecord> uploadRecords = [];
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
    uploadRecords.add(
      _UploadRecord(
        variant: _UploadedVariant.thumbnail,
        usesFirstPrivateImageGrant: usesFirstPrivateImageGrant,
      ),
    );

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
    uploadRecords.add(
      _UploadRecord(
        variant: _UploadedVariant.full,
        usesFirstPrivateImageGrant: usesFirstPrivateImageGrant,
      ),
    );

    if (failFullUpload) {
      throw StateError('Full image upload failed.');
    }

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

    if (deleteFailures.contains(path)) {
      throw StateError('Could not delete $path.');
    }

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

final class _UploadRecord {
  const _UploadRecord({
    required this.variant,
    required this.usesFirstPrivateImageGrant,
  });

  final _UploadedVariant variant;
  final bool usesFirstPrivateImageGrant;
}

final class _GrantCall {
  const _GrantCall({
    required this.peerId,
    required this.chatId,
    required this.messageId,
    required this.version,
  });

  final String peerId;
  final String chatId;
  final String messageId;
  final String version;
}
