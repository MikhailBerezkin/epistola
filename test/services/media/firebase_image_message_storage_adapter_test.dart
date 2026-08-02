import 'dart:io';

import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/services/media/firebase_image_message_storage_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseImageMessageStorageAdapter', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'epistola-image-message-storage-',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('uploads a thumbnail with exact canonical metadata', () async {
      final sourceFile = await _createFile(
        directory: temporaryDirectory,
        name: 'thumb.jpg',
        sizeBytes: 24 * 1024,
      );

      File? uploadedFile;
      String? uploadedPath;
      String? uploadedContentType;
      Map<String, String>? uploadedMetadata;

      final adapter = FirebaseImageMessageStorageAdapter(
        upload:
            ({
              required File file,
              required String path,
              required String contentType,
              required Map<String, String> customMetadata,
            }) async {
              uploadedFile = file;
              uploadedPath = path;
              uploadedContentType = contentType;
              uploadedMetadata = Map<String, String>.from(customMetadata);
            },
        delete: (path) async {},
      );

      final asset = await adapter.uploadThumbnail(
        file: sourceFile,
        uploaderId: 'user-1',
        chatId: 'user-1_user-2',
        messageId: 'message-1',
        version: 1,
        width: 320,
        height: 240,
      );

      expect(uploadedFile, same(sourceFile));
      expect(
        uploadedPath,
        'chat_media/user-1_user-2/'
        'messages/message-1/v1/thumb.jpg',
      );
      expect(uploadedContentType, ImageMessageMetadata.supportedMimeType);
      expect(uploadedMetadata, {
        'uploaderId': 'user-1',
        'chatId': 'user-1_user-2',
        'messageId': 'message-1',
        'version': 'v1',
      });

      expect(asset.path, uploadedPath);
      expect(asset.type, ImageMessageMetadata.thumbnailAssetType);
      expect(asset.ownerType, ImageMessageMetadata.messageOwnerType);
      expect(asset.ownerId, 'message-1');
      expect(asset.sizeBytes, 24 * 1024);
      expect(asset.width, 320);
      expect(asset.height, 240);
      expect(asset.version, 1);
      expect(asset.downloadUrl, isNull);
    });

    test(
      'adds the server-grant metadata to a first private full image',
      () async {
        final sourceFile = await _createFile(
          directory: temporaryDirectory,
          name: 'full.jpg',
          sizeBytes: 280 * 1024,
        );

        String? uploadedPath;
        Map<String, String>? uploadedMetadata;

        final adapter = FirebaseImageMessageStorageAdapter(
          upload:
              ({
                required File file,
                required String path,
                required String contentType,
                required Map<String, String> customMetadata,
              }) async {
                uploadedPath = path;
                uploadedMetadata = Map<String, String>.from(customMetadata);
              },
          delete: (path) async {},
        );

        final asset = await adapter.uploadFull(
          file: sourceFile,
          uploaderId: 'user-1',
          chatId: 'user-1_user-3',
          messageId: 'first-image-message',
          version: 2,
          width: 1280,
          height: 960,
          usesFirstPrivateImageGrant: true,
        );

        expect(
          uploadedPath,
          'chat_media/user-1_user-3/'
          'messages/first-image-message/v2/full.jpg',
        );
        expect(uploadedMetadata, {
          'uploaderId': 'user-1',
          'chatId': 'user-1_user-3',
          'messageId': 'first-image-message',
          'version': 'v2',
          'uploadGrantType': 'first_private_image',
        });

        expect(asset.type, ImageMessageMetadata.fullAssetType);
        expect(asset.width, 1280);
        expect(asset.height, 960);
        expect(asset.version, 2);
      },
    );

    test('rejects an oversized thumbnail before upload', () async {
      final sourceFile = await _createFile(
        directory: temporaryDirectory,
        name: 'oversized-thumb.jpg',
        sizeBytes: (128 * 1024) + 1,
      );

      var uploadCount = 0;

      final adapter = FirebaseImageMessageStorageAdapter(
        upload:
            ({
              required File file,
              required String path,
              required String contentType,
              required Map<String, String> customMetadata,
            }) async {
              uploadCount += 1;
            },
        delete: (path) async {},
      );

      final result = adapter.uploadThumbnail(
        file: sourceFile,
        uploaderId: 'user-1',
        chatId: 'user-1_user-2',
        messageId: 'message-1',
        version: 1,
        width: 320,
        height: 240,
      );

      await expectLater(result, throwsArgumentError);

      expect(uploadCount, 0);
    });

    test('rejects invalid dimensions before upload', () async {
      final sourceFile = await _createFile(
        directory: temporaryDirectory,
        name: 'invalid-dimensions.jpg',
        sizeBytes: 24 * 1024,
      );

      var uploadCount = 0;

      final adapter = FirebaseImageMessageStorageAdapter(
        upload:
            ({
              required File file,
              required String path,
              required String contentType,
              required Map<String, String> customMetadata,
            }) async {
              uploadCount += 1;
            },
        delete: (path) async {},
      );

      final result = adapter.uploadThumbnail(
        file: sourceFile,
        uploaderId: 'user-1',
        chatId: 'user-1_user-2',
        messageId: 'message-1',
        version: 1,
        width: 481,
        height: 240,
      );

      await expectLater(result, throwsArgumentError);

      expect(uploadCount, 0);
    });

    test('deletes only canonical image-message paths', () async {
      final deletedPaths = <String>[];

      final adapter = FirebaseImageMessageStorageAdapter(
        upload:
            ({
              required File file,
              required String path,
              required String contentType,
              required Map<String, String> customMetadata,
            }) async {},
        delete: (path) async {
          deletedPaths.add(path);
        },
      );

      const canonicalPath =
          'chat_media/user-1_user-2/'
          'messages/message-1/v1/full.jpg';

      await adapter.deleteFile(canonicalPath);

      expect(deletedPaths, [canonicalPath]);

      expect(
        () => adapter.deleteFile('user_avatars/user-1/v1/full.jpg'),
        throwsArgumentError,
      );

      expect(deletedPaths, [canonicalPath]);
    });
  });
}

Future<File> _createFile({
  required Directory directory,
  required String name,
  required int sizeBytes,
}) {
  final file = File('${directory.path}${Platform.pathSeparator}$name');

  return file.writeAsBytes(List<int>.filled(sizeBytes, 0), flush: true);
}
