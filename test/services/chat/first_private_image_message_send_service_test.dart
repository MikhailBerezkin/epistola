import 'dart:io';

import 'package:epistola/domain/models/image_message_metadata.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/models/app_user.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/chat/existing_image_message_write_service.dart';
import 'package:epistola/services/chat/first_private_image_message_send_service.dart';
import 'package:epistola/services/chat/first_private_image_message_write_service.dart';
import 'package:epistola/services/chat/image_message_remote_cleanup_service.dart';
import 'package:epistola/services/media/image_message_image_processor.dart';
import 'package:epistola/services/media/image_message_storage_gateway.dart';
import 'package:epistola/services/media/image_message_upload_service.dart';
import 'package:epistola/services/media/media_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirstPrivateImageMessageSendService', () {
    late Directory testDirectory;
    late File sourceFile;

    setUp(() async {
      testDirectory = await Directory.systemTemp.createTemp(
        'epistola_first_private_image_send_test_',
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

    test(
      'creates grant, uploads files and writes the first image message',
      () async {
        final preparedImages = await _prepareImages(sourceFile);

        final events = <String>[];
        final grantCalls = <_GrantCall>[];

        final storage = _FakeImageMessageStorageGateway(events: events);

        final committedWrites = <_CommittedWrite>[];

        final writer = _createWriter(
          messageId: 'message-1',
          events: events,
          onCommit:
              ({
                required String chatId,
                required String messageId,
                required String currentUserId,
                required String peerId,
                required Map<String, dynamic> messageData,
                required Map<String, dynamic> newChatData,
                required Map<String, dynamic> existingChatUpdateData,
              }) async {
                committedWrites.add(
                  _CommittedWrite(
                    chatId: chatId,
                    messageId: messageId,
                    currentUserId: currentUserId,
                    peerId: peerId,
                    messageData: messageData,
                    newChatData: newChatData,
                    existingChatUpdateData: existingChatUpdateData,
                  ),
                );
              },
        );

        final service = _createService(
          writer: writer,
          storage: storage,
          events: events,
          grantCalls: grantCalls,
        );

        final result = await service.sendPreparedImage(
          preparedImages: preparedImages,
          uploaderId: 'user-1',
          otherUser: _peerUser(),
          version: 2,
        );

        expect(result.chatId, 'user-1_user-2');

        expect(result.messageId, 'message-1');

        expect(result.metadata.version, 2);

        expect(result.metadata.hasPersistableMetadata, isTrue);

        expect(events, ['grant', 'upload-thumbnail', 'upload-full', 'commit']);

        expect(grantCalls, hasLength(1));

        final grantCall = grantCalls.single;

        expect(grantCall.peerId, 'user-2');

        expect(grantCall.chatId, 'user-1_user-2');

        expect(grantCall.messageId, 'message-1');

        expect(grantCall.version, 'v2');

        expect(storage.uploadRecords, hasLength(2));

        for (final record in storage.uploadRecords) {
          expect(record.usesFirstPrivateImageGrant, isTrue);
        }

        expect(committedWrites, hasLength(1));

        final committed = committedWrites.single;

        expect(committed.chatId, 'user-1_user-2');

        expect(committed.messageId, 'message-1');

        expect(committed.currentUserId, 'user-1');

        expect(committed.peerId, 'user-2');

        expect(committed.messageData['messageType'], 'image');

        expect(committed.messageData['text'], '');

        expect(committed.newChatData['type'], 'private');

        expect(committed.newChatData['memberIds'], ['user-1', 'user-2']);

        expect(committed.newChatData['lastMessage'], 'Фотография');

        expect(committed.newChatData['lastMessageId'], 'message-1');

        expect(committed.newChatData['firstMessageId'], 'message-1');

        expect(committed.existingChatUpdateData['lastMessage'], 'Фотография');

        expect(storage.deleteAttempts, isEmpty);

        expect(await preparedImages.thumbnailFile.exists(), isFalse);

        expect(await preparedImages.fullFile.exists(), isFalse);

        expect(await sourceFile.exists(), isTrue);
      },
    );

    test(
      'rolls back uploaded files after a confirmed transaction failure',
      () async {
        final preparedImages = await _prepareImages(sourceFile);

        final events = <String>[];
        final grantCalls = <_GrantCall>[];

        final storage = _FakeImageMessageStorageGateway(events: events);

        final writer = _createWriter(
          messageId: 'message-2',
          events: events,
          onCommit:
              ({
                required String chatId,
                required String messageId,
                required String currentUserId,
                required String peerId,
                required Map<String, dynamic> messageData,
                required Map<String, dynamic> newChatData,
                required Map<String, dynamic> existingChatUpdateData,
              }) async {
                throw StateError('Firestore transaction rejected.');
              },
        );

        final service = _createService(
          writer: writer,
          storage: storage,
          events: events,
          grantCalls: grantCalls,
        );

        final result = service.sendPreparedImage(
          preparedImages: preparedImages,
          uploaderId: 'user-1',
          otherUser: _peerUser(),
        );

        await expectLater(
          result,
          throwsA(
            isA<FirstPrivateImageMessageSendException>()
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

        expect(grantCalls, hasLength(1));

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
      },
    );

    test('defers cleanup when the transaction result is uncertain', () async {
      final preparedImages = await _prepareImages(sourceFile);

      final events = <String>[];
      final grantCalls = <_GrantCall>[];

      final storage = _FakeImageMessageStorageGateway(events: events);

      final writer = _createWriter(
        messageId: 'message-3',
        events: events,
        onCommit:
            ({
              required String chatId,
              required String messageId,
              required String currentUserId,
              required String peerId,
              required Map<String, dynamic> messageData,
              required Map<String, dynamic> newChatData,
              required Map<String, dynamic> existingChatUpdateData,
            }) async {
              throw StateError('The transaction result is uncertain.');
            },
      );

      final service = _createService(
        writer: writer,
        storage: storage,
        events: events,
        grantCalls: grantCalls,
        rollbackPolicy: (_) => false,
      );

      final result = service.sendPreparedImage(
        preparedImages: preparedImages,
        uploaderId: 'user-1',
        otherUser: _peerUser(),
        version: 3,
      );

      await expectLater(
        result,
        throwsA(
          isA<FirstPrivateImageMessageSendException>()
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

      expect(grantCalls, hasLength(1));

      expect(storage.uploadRecords, hasLength(2));
      expect(storage.deleteAttempts, isEmpty);
      expect(storage.deletedPaths, isEmpty);

      expect(await preparedImages.thumbnailFile.exists(), isFalse);

      expect(await preparedImages.fullFile.exists(), isFalse);

      expect(await sourceFile.exists(), isTrue);
    });

    test('does not upload or write when grant creation fails', () async {
      final preparedImages = await _prepareImages(sourceFile);

      final events = <String>[];
      final storage = _FakeImageMessageStorageGateway(events: events);

      var commitCount = 0;

      final writer = _createWriter(
        messageId: 'message-4',
        events: events,
        onCommit:
            ({
              required String chatId,
              required String messageId,
              required String currentUserId,
              required String peerId,
              required Map<String, dynamic> messageData,
              required Map<String, dynamic> newChatData,
              required Map<String, dynamic> existingChatUpdateData,
            }) async {
              commitCount += 1;
            },
      );

      final uploadService = ImageMessageUploadService(
        storage: storage,
        createGrant:
            ({
              required String peerId,
              required String chatId,
              required String messageId,
              required String version,
            }) async {
              events.add('grant');

              throw StateError('Grant creation failed.');
            },
      );

      final service = FirstPrivateImageMessageSendService(
        writer: writer,
        uploadService: uploadService,
        cleanupService: ImageMessageRemoteCleanupService(gateway: storage),
      );

      final result = service.sendPreparedImage(
        preparedImages: preparedImages,
        uploaderId: 'user-1',
        otherUser: _peerUser(),
      );

      await expectLater(
        result,
        throwsA(
          isA<ImageMessageUploadException>()
              .having((error) => error.cause, 'cause', isA<StateError>())
              .having(
                (error) => error.requiredRemoteRollback,
                'requiredRemoteRollback',
                isFalse,
              ),
        ),
      );

      expect(events, ['grant']);

      expect(storage.uploadRecords, isEmpty);
      expect(storage.deleteAttempts, isEmpty);
      expect(commitCount, 0);

      expect(await preparedImages.thumbnailFile.exists(), isFalse);

      expect(await preparedImages.fullFile.exists(), isFalse);

      expect(await sourceFile.exists(), isTrue);
    });
  });
}

FirstPrivateImageMessageSendService _createService({
  required FirstPrivateImageMessageWriteService writer,
  required _FakeImageMessageStorageGateway storage,
  required List<String> events,
  required List<_GrantCall> grantCalls,
  FirstPrivateImageMessageWriteRollbackPolicy? rollbackPolicy,
}) {
  final uploadService = ImageMessageUploadService(
    storage: storage,
    createGrant:
        ({
          required String peerId,
          required String chatId,
          required String messageId,
          required String version,
        }) async {
          events.add('grant');

          grantCalls.add(
            _GrantCall(
              peerId: peerId,
              chatId: chatId,
              messageId: messageId,
              version: version,
            ),
          );
        },
  );

  return FirstPrivateImageMessageSendService(
    writer: writer,
    uploadService: uploadService,
    cleanupService: ImageMessageRemoteCleanupService(gateway: storage),
    rollbackPolicy: rollbackPolicy,
  );
}

FirstPrivateImageMessageWriteService _createWriter({
  required String messageId,
  required List<String> events,
  required FirstPrivateImageMessageCommitter onCommit,
}) {
  final createdAt = Object();

  return FirstPrivateImageMessageWriteService(
    createMessageId: (_) => messageId,
    loadSender: () async {
      return const ImageMessageSenderIdentity(
        userId: 'user-1',
        email: 'user@example.com',
        name: 'Пользователь',
      );
    },
    createTimestamp: () => createdAt,
    commit:
        ({
          required String chatId,
          required String messageId,
          required String currentUserId,
          required String peerId,
          required Map<String, dynamic> messageData,
          required Map<String, dynamic> newChatData,
          required Map<String, dynamic> existingChatUpdateData,
        }) async {
          events.add('commit');

          await onCommit(
            chatId: chatId,
            messageId: messageId,
            currentUserId: currentUserId,
            peerId: peerId,
            messageData: messageData,
            newChatData: newChatData,
            existingChatUpdateData: existingChatUpdateData,
          );
        },
  );
}

AppUser _peerUser() {
  return const AppUser(
    uid: 'user-2',
    email: 'peer@example.com',
    name: 'Собеседник',
    phone: '',
    about: '',
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
  _FakeImageMessageStorageGateway({required this.events});

  final List<String> events;

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
    events.add('upload-thumbnail');

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
    events.add('upload-full');

    uploadRecords.add(
      _UploadRecord(
        variant: _UploadedVariant.full,
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

final class _CommittedWrite {
  const _CommittedWrite({
    required this.chatId,
    required this.messageId,
    required this.currentUserId,
    required this.peerId,
    required this.messageData,
    required this.newChatData,
    required this.existingChatUpdateData,
  });

  final String chatId;
  final String messageId;
  final String currentUserId;
  final String peerId;
  final Map<String, dynamic> messageData;
  final Map<String, dynamic> newChatData;
  final Map<String, dynamic> existingChatUpdateData;
}
