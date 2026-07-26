import 'avatar_image_picker_gateway.dart';
import 'image_picker_avatar_image_picker_gateway.dart';

class AvatarImagePickerService {
  AvatarImagePickerService({AvatarImagePickerGateway? gateway})
    : _gateway = gateway ?? ImagePickerAvatarImagePickerGateway();

  final AvatarImagePickerGateway _gateway;

  Future<AvatarPickedImage?> pickFromGallery() {
    return _gateway.pickImage(AvatarImagePickSource.gallery);
  }

  Future<AvatarPickedImage?> takeWithCamera() {
    return _gateway.pickImage(AvatarImagePickSource.camera);
  }

  Future<AvatarPickedImage?> recoverLostImage() async {
    final images = await _gateway.retrieveLostImages();

    if (images.isEmpty) {
      return null;
    }

    // Avatar selection is single-image. If the platform unexpectedly recovers
    // multiple files, consistently keep the first and ignore the rest.
    return images.first;
  }
}
