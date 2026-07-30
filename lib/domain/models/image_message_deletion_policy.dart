enum ImageMessageDeletionScope { currentUser, everyone }

enum ImageMessageAssetDisposition {
  keepForOtherParticipants,
  retainAfterLogicalDeletion,
}

final class ImageMessageDeletionDecision {
  const ImageMessageDeletionDecision._({
    required this.scope,
    required this.assetDisposition,
  });

  final ImageMessageDeletionScope scope;
  final ImageMessageAssetDisposition assetDisposition;

  bool get shouldDeleteStorageImmediately => false;

  bool get requiresLogicalMessageDeletion {
    return scope == ImageMessageDeletionScope.everyone;
  }

  bool get remainsVisibleToOtherParticipants {
    return scope == ImageMessageDeletionScope.currentUser;
  }

  bool get isEligibleForFutureRetentionCleanup {
    return assetDisposition ==
        ImageMessageAssetDisposition.retainAfterLogicalDeletion;
  }
}

final class ImageMessageDeletionPolicy {
  const ImageMessageDeletionPolicy._();

  static ImageMessageDeletionDecision decide(ImageMessageDeletionScope scope) {
    return switch (scope) {
      ImageMessageDeletionScope.currentUser =>
        const ImageMessageDeletionDecision._(
          scope: ImageMessageDeletionScope.currentUser,
          assetDisposition:
              ImageMessageAssetDisposition.keepForOtherParticipants,
        ),
      ImageMessageDeletionScope.everyone =>
        const ImageMessageDeletionDecision._(
          scope: ImageMessageDeletionScope.everyone,
          assetDisposition:
              ImageMessageAssetDisposition.retainAfterLogicalDeletion,
        ),
    };
  }
}
