import 'avatar_image_crop_gateway.dart';
import 'image_cropper_avatar_image_crop_gateway.dart';

class AvatarImageCropService {
  AvatarImageCropService({AvatarImageCropGateway? gateway})
    : _gateway = gateway ?? ImageCropperAvatarImageCropGateway();

  final AvatarImageCropGateway _gateway;

  Future<AvatarCroppedImage?> crop(String sourcePath) {
    _validateSourcePath(sourcePath);
    return _gateway.cropSquare(sourcePath);
  }

  static void _validateSourcePath(String sourcePath) {
    if (sourcePath.trim().isEmpty) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'Source path must not be empty.',
      );
    }
  }
}
