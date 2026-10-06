import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../avatar/avatar_image_picker_gateway.dart';
import '../../avatar/avatar_image_picker_service.dart';
import 'vessel_photo_processor.dart';

typedef VesselPhotoCropper = Future<String?> Function(String sourcePath);

final class VesselPhotoPreparationService {
  VesselPhotoPreparationService({
    AvatarImagePickerService? picker,
    VesselPhotoProcessor? processor,
    VesselPhotoCropper? cropImage,
  }) : _picker = picker ?? AvatarImagePickerService(),
       _processor = processor ?? VesselPhotoProcessor(),
       _cropImage = cropImage ?? _cropWithEditor;

  final AvatarImagePickerService _picker;
  final VesselPhotoProcessor _processor;
  final VesselPhotoCropper _cropImage;

  Future<PreparedVesselPhotoImages?> prepareFromGallery() {
    return _prepare(_picker.pickFromGallery);
  }

  Future<PreparedVesselPhotoImages?> prepareWithCamera() {
    return _prepare(_picker.takeWithCamera);
  }

  Future<PreparedVesselPhotoImages?> prepareRecoveredLostImage() {
    return _prepare(_picker.recoverLostImage);
  }

  Future<PreparedVesselPhotoImages?> _prepare(
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

      // Единый формат фотографии судна.
      //
      // Пользователь заранее видит ровно ту область,
      // которая затем попадёт в аватар и full-photo.
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),

      compressFormat: ImageCompressFormat.jpg,

      // Здесь не экономим качество:
      // финальное сжатие выполняет VesselPhotoProcessor.
      compressQuality: 100,

      uiSettings: <PlatformUiSettings>[
        AndroidUiSettings(
          toolbarTitle: 'Фото судна',
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

          // Рамку можно двигать и менять её размер,
          // но соотношение сторон всегда остаётся 16:9.
          lockAspectRatio: true,
          hideBottomControls: false,

          statusBarLight: false,
          navBarLight: false,

          initAspectRatio: CropAspectRatioPreset.ratio16x9,

          cropStyle: CropStyle.rectangle,

          aspectRatioPresets: const <CropAspectRatioPresetData>[
            CropAspectRatioPreset.ratio16x9,
          ],
        ),

        IOSUiSettings(
          title: 'Фото судна',
          doneButtonTitle: 'Готово',
          cancelButtonTitle: 'Отмена',
          showCancelConfirmationDialog: true,

          rotateButtonsHidden: false,
          resetButtonHidden: false,

          // Формат фиксирован — отдельный выбор
          // пропорций пользователю больше не нужен.
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
          aspectRatioLockEnabled: true,

          cropStyle: CropStyle.rectangle,

          aspectRatioPresets: const <CropAspectRatioPresetData>[
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
    if (_samePath(sourcePath, croppedPath)) {
      return;
    }

    try {
      final croppedFile = File(croppedPath);

      if (await croppedFile.exists()) {
        await croppedFile.delete();
      }
    } catch (_) {
      // Ошибка очистки временного crop-файла
      // не должна отменять подготовленное изображение.
    }
  }

  static bool _samePath(String first, String second) {
    final firstUri = File(first).absolute.uri.normalizePath();

    final secondUri = File(second).absolute.uri.normalizePath();

    if (Platform.isWindows) {
      return firstUri.toString().toLowerCase() ==
          secondUri.toString().toLowerCase();
    }

    return firstUri == secondUri;
  }
}
