abstract final class ImageMessageLimits {
  static const int maxThumbnailSizeBytes = 128 * 1024;

  static const int targetFullSizeBytes = 512 * 1024;
  static const int maxFullSizeBytes = 1024 * 1024;

  static const int maxThumbnailDimension = 480;
  static const int maxFullDimension = 1920;

  /// Допускает небольшое расхождение пропорций из-за округления размеров.
  static const double maxAspectRatioDifference = 0.02;
}
