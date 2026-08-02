import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../avatar/avatar_image_picker_gateway.dart';
import '../avatar/avatar_image_picker_service.dart';
import 'image_message_image_processor.dart';

typedef ImageMessageImageCropper = Future<String?> Function(String sourcePath);

final class ImageMessageImagePreparationService {
  ImageMessageImagePreparationService({
    AvatarImagePickerService? picker,
    ImageMessageImageProcessor? processor,
    ImageMessageImageCropper? cropImage,
  }) : _picker = picker ?? AvatarImagePickerService(),
       _processor = processor ?? ImageMessageImageProcessor(),
       _cropImage = cropImage ?? _cropWithEditor;

  final AvatarImagePickerService _picker;
  final ImageMessageImageProcessor _processor;
  final ImageMessageImageCropper _cropImage;

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

    final croppedPath = await _cropImage(pickedImage.path);

    if (croppedPath == null) {
      return null;
    }

    try {
      return await _processor.process(croppedPath);
    } finally {
      await _deleteTemporaryCrop(
        sourcePath: pickedImage.path,
        croppedPath: croppedPath,
      );
    }
  }

  static Future<String?> _cropWithEditor(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Редактирование фотографии',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: Colors.white,
          dimmedLayerColor: Colors.black54,
          cropFrameColor: Colors.white,
          cropGridColor: Colors.white70,
          cropFrameStrokeWidth: 2,
          cropGridStrokeWidth: 1,
          cropGridRowCount: 3,
          cropGridColumnCount: 3,
          showCropGrid: true,
          lockAspectRatio: false,
          hideBottomControls: false,
          statusBarLight: false,
          navBarLight: false,
          initAspectRatio: CropAspectRatioPreset.original,
          cropStyle: CropStyle.rectangle,
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Редактирование фотографии',
          doneButtonTitle: 'Готово',
          cancelButtonTitle: 'Отмена',
          showCancelConfirmationDialog: true,
          rotateButtonsHidden: false,
          resetButtonHidden: false,
          aspectRatioPickerButtonHidden: false,
          resetAspectRatioEnabled: true,
          aspectRatioLockEnabled: false,
          cropStyle: CropStyle.rectangle,
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    return croppedFile?.path;
  }

  static Future<void> _deleteTemporaryCrop({
    required String sourcePath,
    required String croppedPath,
  }) async {
    if (croppedPath == sourcePath) {
      return;
    }

    try {
      final croppedFile = File(croppedPath);

      if (await croppedFile.exists()) {
        await croppedFile.delete();
      }
    } catch (_) {
      // Ошибка удаления временного файла
      // не должна отменять готовую отправку.
    }
  }
}
