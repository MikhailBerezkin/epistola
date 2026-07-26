import 'package:epistola/services/avatar/avatar_compression_policy.dart';
import 'package:epistola/services/avatar/avatar_image_pipeline_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const desiredMaximum = AvatarImagePipelineConfig.desiredFullSizeBytes;
  const hardMaximum = AvatarImagePipelineConfig.hardFullSizeBytes;
  final lastAttemptIndex =
      AvatarImagePipelineConfig.full.qualityAttempts.length - 1;

  group('AvatarCompressionPolicy.evaluateFullImage', () {
    test('accepts a file at the desired maximum', () {
      final decision = AvatarCompressionPolicy.evaluateFullImage(
        fileSizeBytes: desiredMaximum,
        qualityAttemptIndex: 0,
      );

      expect(decision, AvatarCompressionDecision.accept);
    });

    test('accepts a small file without trying a higher quality', () {
      final decision = AvatarCompressionPolicy.evaluateFullImage(
        fileSizeBytes: 64 * 1024,
        qualityAttemptIndex: 4,
      );

      expect(decision, AvatarCompressionDecision.accept);
    });

    test(
      'requests recompression above the desired maximum when attempts remain',
      () {
        final decision = AvatarCompressionPolicy.evaluateFullImage(
          fileSizeBytes: desiredMaximum + 1,
          qualityAttemptIndex: 0,
        );

        expect(decision, AvatarCompressionDecision.recompress);
      },
    );

    test('keeps recompressing above the hard maximum when attempts remain', () {
      final decision = AvatarCompressionPolicy.evaluateFullImage(
        fileSizeBytes: hardMaximum + 1,
        qualityAttemptIndex: lastAttemptIndex - 1,
      );

      expect(decision, AvatarCompressionDecision.recompress);
    });

    test('accepts a file within the hard maximum after the last attempt', () {
      final decision = AvatarCompressionPolicy.evaluateFullImage(
        fileSizeBytes: hardMaximum,
        qualityAttemptIndex: lastAttemptIndex,
      );

      expect(decision, AvatarCompressionDecision.accept);
    });

    test('reports the hard maximum separately after the last attempt', () {
      final decision = AvatarCompressionPolicy.evaluateFullImage(
        fileSizeBytes: hardMaximum + 1,
        qualityAttemptIndex: lastAttemptIndex,
      );

      expect(decision, AvatarCompressionDecision.hardMaximumExceeded);
    });

    test('rejects an invalid quality attempt index', () {
      expect(
        () => AvatarCompressionPolicy.evaluateFullImage(
          fileSizeBytes: desiredMaximum,
          qualityAttemptIndex: lastAttemptIndex + 1,
        ),
        throwsRangeError,
      );
    });
  });

  group('AvatarCompressionPolicy.exceedsHardMaximum', () {
    test('distinguishes the hard maximum boundary', () {
      expect(AvatarCompressionPolicy.exceedsHardMaximum(hardMaximum), isFalse);
      expect(
        AvatarCompressionPolicy.exceedsHardMaximum(hardMaximum + 1),
        isTrue,
      );
    });

    test('rejects a negative file size', () {
      expect(
        () => AvatarCompressionPolicy.exceedsHardMaximum(-1),
        throwsArgumentError,
      );
    });
  });
}
