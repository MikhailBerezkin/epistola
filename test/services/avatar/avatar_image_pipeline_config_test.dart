import 'package:epistola/services/avatar/avatar_image_pipeline_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarImagePipelineConfig thumbnail', () {
    test('uses JPEG at 128x128 and quality 75', () {
      expect(
        AvatarImagePipelineConfig.thumbnail.format,
        AvatarImageFormat.jpeg,
      );
      expect(AvatarImagePipelineConfig.thumbnail.width, 128);
      expect(AvatarImagePipelineConfig.thumbnail.height, 128);
      expect(AvatarImagePipelineConfig.thumbnail.qualityAttempts, [75]);
      expect(AvatarImagePipelineConfig.hardThumbnailSizeBytes, 128 * 1024);
    });
  });

  group('AvatarImagePipelineConfig full', () {
    test('uses JPEG at 512x512', () {
      expect(AvatarImagePipelineConfig.full.format, AvatarImageFormat.jpeg);
      expect(AvatarImagePipelineConfig.full.width, 512);
      expect(AvatarImagePipelineConfig.full.height, 512);
    });

    test('uses descending quality attempts', () {
      expect(AvatarImagePipelineConfig.full.qualityAttempts, [
        82,
        76,
        70,
        64,
        58,
        52,
        46,
        40,
        34,
      ]);
    });

    test('uses desired and hard byte limits', () {
      expect(AvatarImagePipelineConfig.desiredFullSizeBytes, 300 * 1024);
      expect(AvatarImagePipelineConfig.hardFullSizeBytes, 512 * 1024);
    });

    test('keeps quality attempts immutable', () {
      expect(
        () => AvatarImagePipelineConfig.full.qualityAttempts.add(28),
        throwsUnsupportedError,
      );
    });
  });
}
