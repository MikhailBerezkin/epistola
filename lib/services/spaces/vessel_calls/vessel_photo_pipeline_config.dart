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
  // При обязательном crop 16:9 фактический thumbnail
  // будет максимум примерно 640 x 360.
  //
  // Этого с большим запасом хватает для аватара
  // в списке судов.
  static const thumbnail = VesselPhotoVariantConfig(
    maxDimension: 640,
    qualityAttempts: <int>[86, 80, 74, 68, 62, 56, 50],
    hardMaximumSizeBytes: 192 * 1024,
  );

  // При crop 16:9 максимальный full будет примерно
  // 2560 x 1440.
  //
  // Сохраняем высокий уровень детализации корпуса,
  // контейнеров, кранов и мелких элементов судна.
  static const full = VesselPhotoVariantConfig(
    maxDimension: 2560,
    qualityAttempts: <int>[92, 88, 84, 80, 76, 72, 68, 64, 60, 56],
    hardMaximumSizeBytes: 2048 * 1024,
  );

  // Раньше было 768 KB.
  // Теперь стараемся удерживать full около 1 MB,
  // прежде чем снижать качество дальше.
  static const int targetFullSizeBytes = 1024 * 1024;

  static const String mimeType = 'image/jpeg';
}
