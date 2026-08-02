import 'package:firebase_core/firebase_core.dart';

import '../../domain/models/image_message_metadata.dart';
import '../media/firebase_image_message_storage_adapter.dart';
import '../media/image_message_image_processor.dart';
import '../media/image_message_storage_gateway.dart';
import '../media/image_message_upload_service.dart';
import 'existing_image_message_write_service.dart';
import 'image_message_remote_cleanup_plan.dart';
import 'image_message_remote_cleanup_service.dart';

typedef ExistingImageMessageWriteRollbackPolicy = bool Function(Object error);

final class ExistingImageMessageSendResult {
  const ExistingImageMessageSendResult({
    required this.messageId,
    required this.metadata,
  });

  final String messageId;
  final ImageMessageMetadata metadata;
}

final class ExistingImageMessageSendException implements Exception {
  const ExistingImageMessageSendException({
    required this.cause,
    required this.causeStackTrace,
    required this.rollbackResult,
    required this.rollbackDeferred,
  });

  final Object cause;
  final StackTrace causeStackTrace;

  final ImageMessageRemoteCleanupResult? rollbackResult;

  /// true означает, что Storage намеренно не очищался:
  /// результат Firestore commit мог быть успешным, но неподтверждённым.
  final bool rollbackDeferred;

  bool get rollbackAttempted => rollbackResult != null;

  bool get rollbackCompleted {
    return rollbackResult?.isComplete == true;
  }

  bool get requiresReconciliation {
    return rollbackDeferred || (rollbackResult?.hasFailures ?? false);
  }

  @override
  String toString() {
    if (rollbackDeferred) {
      return 'ExistingImageMessageSendException: '
          '$cause. Remote cleanup was deferred because '
          'the Firestore write result is uncertain.';
    }

    final result = rollbackResult;

    if (result == null) {
      return 'ExistingImageMessageSendException: $cause';
    }

    if (result.isComplete) {
      return 'ExistingImageMessageSendException: '
          '$cause. Remote rollback completed.';
    }

    return 'ExistingImageMessageSendException: '
        '$cause. Remote rollback failed for: '
        '${result.failedPaths.join(', ')}.';
  }
}

final class ExistingImageMessageSendService {
  ExistingImageMessageSendService({
    ExistingImageMessageWriteService? writer,
    ImageMessageUploadService? uploadService,
    ImageMessageRemoteCleanupService? cleanupService,
    ImageMessageStorageGateway? storage,
    ExistingImageMessageWriteRollbackPolicy? rollbackPolicy,
  }) {
    ImageMessageStorageGateway? resolvedStorage = storage;

    if (uploadService == null || cleanupService == null) {
      resolvedStorage ??= FirebaseImageMessageStorageAdapter();
    }

    _writer = writer ?? ExistingImageMessageWriteService();

    _uploadService =
        uploadService ?? ImageMessageUploadService(storage: resolvedStorage!);

    _cleanupService =
        cleanupService ??
        ImageMessageRemoteCleanupService(gateway: resolvedStorage!);

    _rollbackPolicy = rollbackPolicy ?? _shouldRollbackWriteFailure;
  }

  late final ExistingImageMessageWriteService _writer;

  late final ImageMessageUploadService _uploadService;

  late final ImageMessageRemoteCleanupService _cleanupService;

  late final ExistingImageMessageWriteRollbackPolicy _rollbackPolicy;

  Future<ExistingImageMessageSendResult> sendPreparedImage({
    required PreparedImageMessageImages preparedImages,
    required String uploaderId,
    required String chatId,
    int version = 1,
  }) async {
    try {
      final messageId = _writer.createMessageId(chatId: chatId);

      final metadata = await _uploadService.uploadPreparedImage(
        preparedImages: preparedImages,
        uploaderId: uploaderId,
        chatId: chatId,
        messageId: messageId,
        version: version,
      );

      try {
        await _writer.writeImageMessage(
          chatId: chatId,
          messageId: messageId,
          metadata: metadata,
        );
      } catch (error, stackTrace) {
        final shouldRollback = _rollbackPolicy(error);

        ImageMessageRemoteCleanupResult? rollbackResult;

        var rollbackDeferred = !shouldRollback;

        if (shouldRollback) {
          final cleanupPlan = ImageMessageRemoteCleanupPlan.tryCreate(
            chatId: chatId,
            messageId: messageId,
            version: version,
          );

          if (cleanupPlan == null) {
            rollbackDeferred = true;
          } else {
            rollbackResult = await _cleanupService.cleanup(cleanupPlan);
          }
        }

        Error.throwWithStackTrace(
          ExistingImageMessageSendException(
            cause: error,
            causeStackTrace: stackTrace,
            rollbackResult: rollbackResult,
            rollbackDeferred: rollbackDeferred,
          ),
          stackTrace,
        );
      }

      return ExistingImageMessageSendResult(
        messageId: messageId,
        metadata: metadata,
      );
    } finally {
      // uploadPreparedImage уже выполняет cleanup,
      // но повторный вызов безопасен и закрывает ошибку,
      // возникшую до запуска upload-сервиса.
      await preparedImages.cleanup();
    }
  }

  static bool _shouldRollbackWriteFailure(Object error) {
    if (error is! FirebaseException) {
      // Ошибки локальной валидации и тестовых адаптеров
      // означают, что Firestore commit не состоялся.
      return true;
    }

    const uncertainCommitCodes = {
      'cancelled',
      'unknown',
      'deadline-exceeded',
      'internal',
      'unavailable',
      'data-loss',
    };

    return !uncertainCommitCodes.contains(error.code);
  }
}
