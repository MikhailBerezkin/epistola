import 'dart:io';

import 'avatar_image_crop_service.dart';
import 'avatar_image_picker_gateway.dart';
import 'avatar_image_picker_service.dart';
import 'avatar_image_processor.dart';

typedef AvatarCroppedImageDeleteInvoker = Future<void> Function(String path);

class AvatarImagePreparationService {
  AvatarImagePreparationService({
    AvatarImagePickerService? picker,
    AvatarImageCropService? cropper,
    AvatarImageProcessor? processor,
    AvatarCroppedImageDeleteInvoker? deleteCroppedImage,
  }) : _picker = picker ?? AvatarImagePickerService(),
       _cropper = cropper ?? AvatarImageCropService(),
       _processor = processor ?? AvatarImageProcessor(),
       _deleteCroppedImage = deleteCroppedImage ?? _deleteFile;

  final AvatarImagePickerService _picker;
  final AvatarImageCropService _cropper;
  final AvatarImageProcessor _processor;
  final AvatarCroppedImageDeleteInvoker _deleteCroppedImage;

  Future<PreparedAvatarImages?> prepareFromGallery() {
    return _prepare(_picker.pickFromGallery);
  }

  Future<PreparedAvatarImages?> prepareWithCamera() {
    return _prepare(_picker.takeWithCamera);
  }

  Future<PreparedAvatarImages?> prepareRecoveredLostImage() {
    return _prepare(_picker.recoverLostImage);
  }

  Future<PreparedAvatarImages?> _prepare(
    Future<AvatarPickedImage?> Function() pickImage,
  ) async {
    final pickedImage = await pickImage();

    if (pickedImage == null) {
      return null;
    }

    final croppedImage = await _cropper.crop(pickedImage.path);

    if (croppedImage == null) {
      return null;
    }

    try {
      return await _processor.process(croppedImage.path);
    } finally {
      await _deleteCroppedImageBestEffort(
        sourcePath: pickedImage.path,
        croppedPath: croppedImage.path,
      );
    }
  }

  Future<void> _deleteCroppedImageBestEffort({
    required String sourcePath,
    required String croppedPath,
  }) async {
    try {
      if (!_samePath(sourcePath, croppedPath)) {
        await _deleteCroppedImage(croppedPath);
      }
    } catch (_) {
      // Cropped-file cleanup must not mask a result or processing failure.
    }
  }

  static bool _samePath(String first, String second) {
    final firstPath = File(first).absolute.uri.normalizePath().toString();
    final secondPath = File(second).absolute.uri.normalizePath().toString();

    if (Platform.isWindows) {
      return firstPath.toLowerCase() == secondPath.toLowerCase();
    }

    return firstPath == secondPath;
  }

  static Future<void> _deleteFile(String path) async {
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }
  }
}
