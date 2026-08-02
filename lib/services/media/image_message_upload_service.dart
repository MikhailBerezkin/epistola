import '../../domain/models/image_message_metadata.dart';
import '../chat/first_private_image_upload_grant_service.dart';
import '../chat/image_message_remote_cleanup_plan.dart';
import '../chat/image_message_remote_cleanup_service.dart';
import 'firebase_image_message_storage_adapter.dart';
import 'image_message_image_processor.dart';
import 'image_message_storage_gateway.dart';

typedef FirstPrivateImageGrantInvoker =
    Future<void> Function({
      required String peerId,
      required String chatId,
      required String messageId,
      required String version,
    });

final class ImageMessageUploadException implements Exception {
  const ImageMessageUploadException({
    required this.cause,
    required this.causeStackTrace,
    required this.rollbackResult,
  });

  final Object cause;
  final StackTrace causeStackTrace;
  final ImageMessageRemoteCleanupResult? rollbackResult;

  bool get requiredRemoteRollback => rollbackResult != null;

  bool get rollbackCompleted {
    final result = rollbackResult;

    return result == null || result.isComplete;
  }

  @override
  String toString() {
    final result = rollbackResult;

    if (result == null) {
      return 'ImageMessageUploadException: $cause';
    }

    if (result.isComplete) {
      return 'ImageMessageUploadException: '
          '$cause. Remote rollback completed.';
    }

    return 'ImageMessageUploadException: '
        '$cause. Remote rollback failed for: '
        '${result.failedPaths.join(', ')}.';
  }
}

final class ImageMessageUploadService {
  ImageMessageUploadService({
    ImageMessageStorageGateway? storage,
    FirstPrivateImageGrantInvoker? createGrant,
    ImageMessageRemoteCleanupService? cleanupService,
  }) {
    final resolvedStorage = storage ?? FirebaseImageMessageStorageAdapter();

    _storage = resolvedStorage;

    _createGrant = createGrant ?? _createDefaultGrantInvoker();

    _cleanupService =
        cleanupService ??
        ImageMessageRemoteCleanupService(gateway: resolvedStorage);
  }

  late final ImageMessageStorageGateway _storage;
  late final FirstPrivateImageGrantInvoker _createGrant;
  late final ImageMessageRemoteCleanupService _cleanupService;

  Future<ImageMessageMetadata> uploadPreparedImage({
    required PreparedImageMessageImages preparedImages,
    required String uploaderId,
    required String chatId,
    required String messageId,
    int version = 1,
    String? firstPrivatePeerId,
  }) async {
    ImageMessageRemoteCleanupResult? rollbackResult;
    var remoteWriteAttempted = false;

    try {
      _validateIdentifier(value: uploaderId, argumentName: 'uploaderId');

      _validateIdentifier(value: chatId, argumentName: 'chatId');

      _validateIdentifier(value: messageId, argumentName: 'messageId');

      if (version <= 0) {
        throw ArgumentError.value(
          version,
          'version',
          'Version must be greater than zero.',
        );
      }

      final peerId = firstPrivatePeerId;

      if (peerId != null) {
        _validateIdentifier(value: peerId, argumentName: 'firstPrivatePeerId');

        if (peerId == uploaderId) {
          throw ArgumentError.value(
            peerId,
            'firstPrivatePeerId',
            'Peer ID must differ from uploader ID.',
          );
        }

        await _createGrant(
          peerId: peerId,
          chatId: chatId,
          messageId: messageId,
          version: 'v$version',
        );
      }

      final usesFirstPrivateImageGrant = peerId != null;

      remoteWriteAttempted = true;

      final thumbnail = await _storage.uploadThumbnail(
        file: preparedImages.thumbnailFile,
        uploaderId: uploaderId,
        chatId: chatId,
        messageId: messageId,
        version: version,
        width: preparedImages.thumbnailWidth,
        height: preparedImages.thumbnailHeight,
        usesFirstPrivateImageGrant: usesFirstPrivateImageGrant,
      );

      final full = await _storage.uploadFull(
        file: preparedImages.fullFile,
        uploaderId: uploaderId,
        chatId: chatId,
        messageId: messageId,
        version: version,
        width: preparedImages.fullWidth,
        height: preparedImages.fullHeight,
        usesFirstPrivateImageGrant: usesFirstPrivateImageGrant,
      );

      final metadata = ImageMessageMetadata(thumbnail: thumbnail, full: full);

      if (!metadata.hasPersistableMetadata) {
        throw StateError('Uploaded image metadata is incomplete.');
      }

      return metadata;
    } catch (error, stackTrace) {
      if (remoteWriteAttempted) {
        final cleanupPlan = ImageMessageRemoteCleanupPlan.tryCreate(
          chatId: chatId,
          messageId: messageId,
          version: version,
        );

        if (cleanupPlan != null) {
          rollbackResult = await _cleanupService.cleanup(cleanupPlan);
        }
      }

      Error.throwWithStackTrace(
        ImageMessageUploadException(
          cause: error,
          causeStackTrace: stackTrace,
          rollbackResult: rollbackResult,
        ),
        stackTrace,
      );
    } finally {
      await preparedImages.cleanup();
    }
  }

  static FirstPrivateImageGrantInvoker _createDefaultGrantInvoker() {
    final service = FirstPrivateImageUploadGrantService();

    return ({
      required String peerId,
      required String chatId,
      required String messageId,
      required String version,
    }) {
      return service.createGrant(
        peerId: peerId,
        chatId: chatId,
        messageId: messageId,
        version: version,
      );
    };
  }

  static void _validateIdentifier({
    required String value,
    required String argumentName,
  }) {
    if (value.isEmpty || value != value.trim()) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must be a non-empty trimmed string.',
      );
    }

    if (value.contains('/')) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must not contain a slash.',
      );
    }
  }
}
