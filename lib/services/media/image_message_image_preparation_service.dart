import '../avatar/avatar_image_picker_gateway.dart';
import '../avatar/avatar_image_picker_service.dart';
import 'image_message_image_processor.dart';

final class ImageMessageImagePreparationService {
  ImageMessageImagePreparationService({
    AvatarImagePickerService? picker,
    ImageMessageImageProcessor? processor,
  }) : _picker = picker ?? AvatarImagePickerService(),
       _processor = processor ?? ImageMessageImageProcessor();

  final AvatarImagePickerService _picker;
  final ImageMessageImageProcessor _processor;

  Future<PreparedImageMessageImages?> prepareFromGallery() {
    return _prepare(_picker.pickFromGallery);
  }

  Future<PreparedImageMessageImages?> prepareWithCamera() {
    return _prepare(_picker.takeWithCamera);
  }

  Future<PreparedImageMessageImages?> prepareRecoveredLostImage() {
    return _prepare(_picker.recoverLostImage);
  }

  Future<PreparedImageMessageImages?> _prepare(
    Future<AvatarPickedImage?> Function() pickImage,
  ) async {
    final pickedImage = await pickImage();

    if (pickedImage == null) {
      return null;
    }

    return _processor.process(pickedImage.path);
  }
}
