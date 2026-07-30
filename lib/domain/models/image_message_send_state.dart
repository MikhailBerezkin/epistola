enum ImageMessageSendPhase {
  idle,
  preparing,
  uploadingThumbnail,
  uploadingFull,
  committingMessage,
  success,
  cancelled,
  failure,
}

enum ImageMessageSendFailureStage {
  preparation,
  thumbnailUpload,
  fullUpload,
  messageCommit,
}

final class ImageMessageSendState {
  const ImageMessageSendState._({
    required this.phase,
    this.failureStage,
    this.error,
  });

  const ImageMessageSendState.idle()
    : this._(phase: ImageMessageSendPhase.idle);

  const ImageMessageSendState.preparing()
    : this._(phase: ImageMessageSendPhase.preparing);

  const ImageMessageSendState.uploadingThumbnail()
    : this._(phase: ImageMessageSendPhase.uploadingThumbnail);

  const ImageMessageSendState.uploadingFull()
    : this._(phase: ImageMessageSendPhase.uploadingFull);

  const ImageMessageSendState.committingMessage()
    : this._(phase: ImageMessageSendPhase.committingMessage);

  const ImageMessageSendState.success()
    : this._(phase: ImageMessageSendPhase.success);

  const ImageMessageSendState.cancelled()
    : this._(phase: ImageMessageSendPhase.cancelled);

  const ImageMessageSendState.failure({
    required ImageMessageSendFailureStage stage,
    required Object error,
  }) : this._(
         phase: ImageMessageSendPhase.failure,
         failureStage: stage,
         error: error,
       );

  final ImageMessageSendPhase phase;
  final ImageMessageSendFailureStage? failureStage;
  final Object? error;

  bool get isBusy {
    return switch (phase) {
      ImageMessageSendPhase.preparing ||
      ImageMessageSendPhase.uploadingThumbnail ||
      ImageMessageSendPhase.uploadingFull ||
      ImageMessageSendPhase.committingMessage => true,
      _ => false,
    };
  }

  bool get isTerminal {
    return switch (phase) {
      ImageMessageSendPhase.success ||
      ImageMessageSendPhase.cancelled ||
      ImageMessageSendPhase.failure => true,
      _ => false,
    };
  }

  int? get completedUploadVariants {
    return switch (phase) {
      ImageMessageSendPhase.uploadingThumbnail => 0,
      ImageMessageSendPhase.uploadingFull => 1,
      ImageMessageSendPhase.committingMessage => 2,
      ImageMessageSendPhase.success => 2,
      _ => null,
    };
  }

  double? get uploadProgress {
    final completed = completedUploadVariants;

    if (completed == null) {
      return null;
    }

    return completed / 2;
  }

  bool get canRetry {
    return phase == ImageMessageSendPhase.failure;
  }

  bool get requiresRemoteRollback {
    return switch (failureStage) {
      ImageMessageSendFailureStage.thumbnailUpload ||
      ImageMessageSendFailureStage.fullUpload ||
      ImageMessageSendFailureStage.messageCommit => true,
      ImageMessageSendFailureStage.preparation || null => false,
    };
  }
}
