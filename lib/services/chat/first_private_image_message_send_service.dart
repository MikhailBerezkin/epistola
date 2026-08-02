import 'package:firebase_core/firebase_core.dart';

import '../../domain/models/image_message_metadata.dart';
import '../../models/app_user.dart';
import '../media/firebase_image_message_storage_adapter.dart';
import '../media/image_message_image_processor.dart';
import '../media/image_message_storage_gateway.dart';
import '../media/image_message_upload_service.dart';
import 'first_private_image_message_write_service.dart';
import 'image_message_remote_cleanup_plan.dart';
import 'image_message_remote_cleanup_service.dart';

typedef FirstPrivateImageMessageWriteRollbackPolicy =
    bool Function(Object error);

final class FirstPrivateImageMessageSendResult {
  const FirstPrivateImageMessageSendResult({
    required this.chatId,
    required this.messageId,
    required this.metadata,
  });

  final String chatId;
  final String messageId;
  final ImageMessageMetadata metadata;
}

final class FirstPrivateImageMessageSendException implements Exception {
  const FirstPrivateImageMessageSendException({
    required this.cause,
    required this.causeStackTrace,
    required this.rollbackResult,
    required this.rollbackDeferred,
  });

  final Object cause;
  final StackTrace causeStackTrace;

  final ImageMessageRemoteCleanupResult? rollbackResult;

  /// true означает, что Storage намеренно не очищался:
  /// результат Firestore-транзакции мог быть успешным,
  /// но клиент не получил подтверждение.
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
      return 'FirstPrivateImageMessageSendException: '
          '$cause. Remote cleanup was deferred because '
          'the Firestore write result is uncertain.';
    }

    final result = rollbackResult;

    if (result == null) {
      return 'FirstPrivateImageMessageSendException: '
          '$cause';
    }

    if (result.isComplete) {
      return 'FirstPrivateImageMessageSendException: '
          '$cause. Remote rollback completed.';
    }

    return 'FirstPrivateImageMessageSendException: '
        '$cause. Remote rollback failed for: '
        '${result.failedPaths.join(', ')}.';
  }
}

final class FirstPrivateImageMessageSendService {
  FirstPrivateImageMessageSendService({
    FirstPrivateImageMessageWriteService? writer,
    ImageMessageUploadService? uploadService,
    ImageMessageRemoteCleanupService? cleanupService,
    ImageMessageStorageGateway? storage,
    FirstPrivateImageMessageWriteRollbackPolicy? rollbackPolicy,
  }) {
    ImageMessageStorageGateway? resolvedStorage = storage;

    if (uploadService == null || cleanupService == null) {
      resolvedStorage ??= FirebaseImageMessageStorageAdapter();
    }

    _writer = writer ?? FirstPrivateImageMessageWriteService();

    _uploadService =
        uploadService ?? ImageMessageUploadService(storage: resolvedStorage!);

    _cleanupService =
        cleanupService ??
        ImageMessageRemoteCleanupService(gateway: resolvedStorage!);

    _rollbackPolicy = rollbackPolicy ?? _shouldRollbackWriteFailure;
  }

  late final FirstPrivateImageMessageWriteService _writer;

  late final ImageMessageUploadService _uploadService;

  late final ImageMessageRemoteCleanupService _cleanupService;

  late final FirstPrivateImageMessageWriteRollbackPolicy _rollbackPolicy;

  Future<FirstPrivateImageMessageSendResult> sendPreparedImage({
    required PreparedImageMessageImages preparedImages,
    required String uploaderId,
    required AppUser otherUser,
    int version = 1,
  }) async {
    try {
      final chatId = _writer.createChatId(
        uploaderId: uploaderId,
        peerId: otherUser.uid,
      );

      final messageId = _writer.createMessageId(chatId: chatId);

      final metadata = await _uploadService.uploadPreparedImage(
        preparedImages: preparedImages,
        uploaderId: uploaderId,
        chatId: chatId,
        messageId: messageId,
        version: version,
        firstPrivatePeerId: otherUser.uid,
      );

      try {
        await _writer.writeFirstImageMessage(
          uploaderId: uploaderId,
          otherUser: otherUser,
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
          FirstPrivateImageMessageSendException(
            cause: error,
            causeStackTrace: stackTrace,
            rollbackResult: rollbackResult,
            rollbackDeferred: rollbackDeferred,
          ),
          stackTrace,
        );
      }

      return FirstPrivateImageMessageSendResult(
        chatId: chatId,
        messageId: messageId,
        metadata: metadata,
      );
    } finally {
      // uploadPreparedImage уже удаляет временные файлы.
      // Повторный cleanup безопасен и закрывает ошибки,
      // возникшие до запуска upload-сервиса.
      await preparedImages.cleanup();
    }
  }

  static bool _shouldRollbackWriteFailure(Object error) {
    if (error is! FirebaseException) {
      // Локальная валидация или подтверждённый отказ
      // означают, что Firestore-транзакция не прошла.
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
