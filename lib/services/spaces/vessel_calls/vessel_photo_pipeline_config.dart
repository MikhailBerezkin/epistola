enum VesselPhotoFormat { jpeg }

final class VesselPhotoVariantConfig {
  const VesselPhotoVariantConfig({
    required this.maxDimension,
    required this.qualityAttempts,
    required this.hardMaximumSizeBytes,
  });

  final int maxDimension;
  final List<int> qualityAttempts;
  final int hardMaximumSizeBytes;
}

abstract final class VesselPhotoPipelineConfig {
  static const thumbnail = VesselPhotoVariantConfig(
    maxDimension: 640,
    qualityAttempts: <int>[86, 80, 74, 68, 62, 56, 50],
    hardMaximumSizeBytes: 192 * 1024,
  );

  static const full = VesselPhotoVariantConfig(
    maxDimension: 2560,
    qualityAttempts: <int>[92, 88, 84, 80, 76, 72, 68, 64, 60, 56],
    hardMaximumSizeBytes: 1536 * 1024,
  );

  static const int targetFullSizeBytes = 768 * 1024;

  static const String mimeType = 'image/jpeg';
}
