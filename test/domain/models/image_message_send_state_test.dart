import 'package:epistola/domain/models/image_message_send_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageMessageSendState', () {
    test('starts idle without progress', () {
      const state = ImageMessageSendState.idle();

      expect(state.phase, ImageMessageSendPhase.idle);
      expect(state.isBusy, isFalse);
      expect(state.isTerminal, isFalse);
      expect(state.completedUploadVariants, isNull);
      expect(state.uploadProgress, isNull);
    });

    test('marks preparation as busy without upload progress', () {
      const state = ImageMessageSendState.preparing();

      expect(state.isBusy, isTrue);
      expect(state.isTerminal, isFalse);
      expect(state.uploadProgress, isNull);
    });

    test('reports thumbnail upload as zero of two completed', () {
      const state = ImageMessageSendState.uploadingThumbnail();

      expect(state.isBusy, isTrue);
      expect(state.completedUploadVariants, 0);
      expect(state.uploadProgress, 0);
    });

    test('reports full upload as one of two completed', () {
      const state = ImageMessageSendState.uploadingFull();

      expect(state.isBusy, isTrue);
      expect(state.completedUploadVariants, 1);
      expect(state.uploadProgress, 0.5);
    });

    test('reports both variants uploaded while committing', () {
      const state = ImageMessageSendState.committingMessage();

      expect(state.isBusy, isTrue);
      expect(state.completedUploadVariants, 2);
      expect(state.uploadProgress, 1);
    });

    test('marks success as terminal with complete progress', () {
      const state = ImageMessageSendState.success();

      expect(state.isBusy, isFalse);
      expect(state.isTerminal, isTrue);
      expect(state.completedUploadVariants, 2);
      expect(state.uploadProgress, 1);
      expect(state.canRetry, isFalse);
    });

    test('marks cancellation as terminal without retry', () {
      const state = ImageMessageSendState.cancelled();

      expect(state.isBusy, isFalse);
      expect(state.isTerminal, isTrue);
      expect(state.canRetry, isFalse);
      expect(state.requiresRemoteRollback, isFalse);
    });

    test('stores preparation failure without remote rollback', () {
      final error = StateError('Preparation failed');

      final state = ImageMessageSendState.failure(
        stage: ImageMessageSendFailureStage.preparation,
        error: error,
      );

      expect(state.phase, ImageMessageSendPhase.failure);
      expect(state.failureStage, ImageMessageSendFailureStage.preparation);
      expect(state.error, same(error));
      expect(state.isTerminal, isTrue);
      expect(state.canRetry, isTrue);
      expect(state.requiresRemoteRollback, isFalse);
    });

    test('requires rollback after an upload or commit failure', () {
      final thumbnailFailure = ImageMessageSendState.failure(
        stage: ImageMessageSendFailureStage.thumbnailUpload,
        error: StateError('Thumbnail upload failed'),
      );

      final fullFailure = ImageMessageSendState.failure(
        stage: ImageMessageSendFailureStage.fullUpload,
        error: StateError('Full upload failed'),
      );

      final commitFailure = ImageMessageSendState.failure(
        stage: ImageMessageSendFailureStage.messageCommit,
        error: StateError('Message commit failed'),
      );

      expect(thumbnailFailure.requiresRemoteRollback, isTrue);
      expect(fullFailure.requiresRemoteRollback, isTrue);
      expect(commitFailure.requiresRemoteRollback, isTrue);
    });
  });
}
