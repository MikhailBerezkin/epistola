import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';

import 'avatar_image_crop_gateway.dart';

typedef AvatarImageCropInvoker = Future<String?> Function(String sourcePath);

final class ImageCropperAvatarImageCropGateway
    implements AvatarImageCropGateway {
  ImageCropperAvatarImageCropGateway({AvatarImageCropInvoker? invoker})
    : _invoker = invoker ?? _invokeImageCropper;

  static const _maximumIntermediateDimension = 1024;
  static const _intermediateQuality = 100;
  static const _squareAspectRatio = CropAspectRatio(ratioX: 1, ratioY: 1);
  static const _fallbackErrorCode = 'crop_failed';
  static const _fallbackErrorMessage = 'Failed to crop the avatar image.';

  final AvatarImageCropInvoker _invoker;

  @override
  Future<AvatarCroppedImage?> cropSquare(String sourcePath) async {
    _validateSourcePath(sourcePath);

    try {
      final croppedPath = await _invoker(sourcePath);

      return croppedPath == null ? null : AvatarCroppedImage(path: croppedPath);
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AvatarImageCropException(
          code: error.code.isEmpty ? _fallbackErrorCode : error.code,
          message: _messageOrFallback(error.message),
        ),
        stackTrace,
      );
    } on AvatarImageCropException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        const AvatarImageCropException(
          code: _fallbackErrorCode,
          message: _fallbackErrorMessage,
        ),
        stackTrace,
      );
    }
  }

  static Future<String?> _invokeImageCropper(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      maxWidth: _maximumIntermediateDimension,
      maxHeight: _maximumIntermediateDimension,
      aspectRatio: _squareAspectRatio,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: _intermediateQuality,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Обрезать фото',
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          cropStyle: CropStyle.rectangle,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          title: 'Обрезать фото',
          doneButtonTitle: 'Готово',
          cancelButtonTitle: 'Отмена',
          cropStyle: CropStyle.rectangle,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
      ],
    );

    return croppedFile?.path;
  }

  static String _messageOrFallback(String? message) {
    return message == null || message.trim().isEmpty
        ? _fallbackErrorMessage
        : message;
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
