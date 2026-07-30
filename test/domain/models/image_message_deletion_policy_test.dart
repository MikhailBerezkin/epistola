import 'package:epistola/domain/models/image_message_deletion_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageMessageDeletionPolicy', () {
    test('keeps assets when deleting only for the current user', () {
      final decision = ImageMessageDeletionPolicy.decide(
        ImageMessageDeletionScope.currentUser,
      );

      expect(
        decision.assetDisposition,
        ImageMessageAssetDisposition.keepForOtherParticipants,
      );
      expect(decision.shouldDeleteStorageImmediately, isFalse);
      expect(decision.requiresLogicalMessageDeletion, isFalse);
      expect(decision.remainsVisibleToOtherParticipants, isTrue);
      expect(decision.isEligibleForFutureRetentionCleanup, isFalse);
    });

    test('retains assets after delete for everyone', () {
      final decision = ImageMessageDeletionPolicy.decide(
        ImageMessageDeletionScope.everyone,
      );

      expect(
        decision.assetDisposition,
        ImageMessageAssetDisposition.retainAfterLogicalDeletion,
      );
      expect(decision.shouldDeleteStorageImmediately, isFalse);
      expect(decision.requiresLogicalMessageDeletion, isTrue);
      expect(decision.remainsVisibleToOtherParticipants, isFalse);
      expect(decision.isEligibleForFutureRetentionCleanup, isTrue);
    });

    test('never performs immediate cleanup for message deletion', () {
      for (final scope in ImageMessageDeletionScope.values) {
        final decision = ImageMessageDeletionPolicy.decide(scope);

        expect(
          decision.shouldDeleteStorageImmediately,
          isFalse,
          reason: 'Message deletion must not act as upload rollback.',
        );
      }
    });
  });
}
