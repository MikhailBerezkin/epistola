import 'avatar_image_pipeline_config.dart';

enum AvatarCompressionDecision { accept, recompress, hardMaximumExceeded }

class AvatarCompressionPolicy {
  const AvatarCompressionPolicy._();

  static AvatarCompressionDecision evaluateFullImage({
    required int fileSizeBytes,
    required int qualityAttemptIndex,
  }) {
    _validateFileSize(fileSizeBytes);
    RangeError.checkValidIndex(
      qualityAttemptIndex,
      AvatarImagePipelineConfig.full.qualityAttempts,
      'qualityAttemptIndex',
    );

    if (fileSizeBytes <= AvatarImagePipelineConfig.desiredFullSizeBytes) {
      return AvatarCompressionDecision.accept;
    }

    final lastAttemptIndex =
        AvatarImagePipelineConfig.full.qualityAttempts.length - 1;

    if (qualityAttemptIndex < lastAttemptIndex) {
      return AvatarCompressionDecision.recompress;
    }

    return exceedsHardMaximum(fileSizeBytes)
        ? AvatarCompressionDecision.hardMaximumExceeded
        : AvatarCompressionDecision.accept;
  }

  static bool exceedsHardMaximum(int fileSizeBytes) {
    _validateFileSize(fileSizeBytes);
    return fileSizeBytes > AvatarImagePipelineConfig.hardFullSizeBytes;
  }

  static void _validateFileSize(int fileSizeBytes) {
    if (fileSizeBytes < 0) {
      throw ArgumentError.value(fileSizeBytes, 'fileSizeBytes');
    }
  }
}
