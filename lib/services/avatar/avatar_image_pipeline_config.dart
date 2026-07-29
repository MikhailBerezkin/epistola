enum AvatarImageFormat { jpeg }

class AvatarImageVariantConfig {
  const AvatarImageVariantConfig._({
    required this.format,
    required this.width,
    required this.height,
    required this.qualityAttempts,
  });

  final AvatarImageFormat format;
  final int width;
  final int height;
  final List<int> qualityAttempts;
}

class AvatarImagePipelineConfig {
  const AvatarImagePipelineConfig._();

  static const thumbnail = AvatarImageVariantConfig._(
    format: AvatarImageFormat.jpeg,
    width: 128,
    height: 128,
    qualityAttempts: [75],
  );

  static const full = AvatarImageVariantConfig._(
    format: AvatarImageFormat.jpeg,
    width: 512,
    height: 512,
    qualityAttempts: [82, 76, 70, 64, 58, 52, 46, 40, 34],
  );

  static const desiredFullSizeBytes = 300 * 1024;
  static const hardThumbnailSizeBytes = 128 * 1024;
  static const hardFullSizeBytes = 512 * 1024;
}
