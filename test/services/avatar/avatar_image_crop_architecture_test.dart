import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crop layer has no Firebase or persistent file-system dependencies', () {
    const cropLayerPaths = [
      'lib/services/avatar/avatar_image_crop_gateway.dart',
      'lib/services/avatar/avatar_image_crop_service.dart',
      'lib/services/avatar/image_cropper_avatar_image_crop_gateway.dart',
    ];

    for (final path in cropLayerPaths) {
      final source = File(path).readAsStringSync();

      expect(source, isNot(contains('package:firebase_')), reason: path);
      expect(source, isNot(contains("'dart:io'")), reason: path);
      expect(source, isNot(contains('.copy(')), reason: path);
      expect(source, isNot(contains('.delete(')), reason: path);
    }
  });

  test(
    'public crop boundary does not expose image_cropper or Flutter types',
    () {
      const publicBoundaryPaths = [
        'lib/services/avatar/avatar_image_crop_gateway.dart',
        'lib/services/avatar/avatar_image_crop_service.dart',
      ];

      for (final path in publicBoundaryPaths) {
        final source = File(path).readAsStringSync();

        expect(source, isNot(contains('package:image_cropper')), reason: path);
        expect(source, isNot(contains('package:flutter')), reason: path);
        expect(source, isNot(contains('CroppedFile')), reason: path);
        expect(source, isNot(contains('UiSettings')), reason: path);
      }
    },
  );

  test('production gateway exposes only a plugin-neutral test seam', () {
    const path =
        'lib/services/avatar/image_cropper_avatar_image_crop_gateway.dart';
    final source = File(path).readAsStringSync();
    final constructor = RegExp(
      r'ImageCropperAvatarImageCropGateway\([^)]*\)',
    ).firstMatch(source)!.group(0)!;

    expect(
      source,
      contains(
        'typedef AvatarImageCropInvoker = '
        'Future<String?> Function(String sourcePath);',
      ),
    );
    expect(source, isNot(contains('class ImageCropperClient')));

    for (final pluginType in [
      'CroppedFile',
      'ImageCropper',
      'CropAspectRatio',
      'ImageCompressFormat',
      'PlatformUiSettings',
      'AndroidUiSettings',
      'IOSUiSettings',
    ]) {
      expect(
        constructor,
        isNot(matches(RegExp('\\b$pluginType\\b'))),
        reason: pluginType,
      );
    }
  });
}
