import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('processor boundary is plugin-neutral and has no app integrations', () {
    const publicBoundaryPaths = [
      'lib/services/avatar/avatar_image_compressor_gateway.dart',
      'lib/services/avatar/avatar_image_processor.dart',
    ];

    for (final path in publicBoundaryPaths) {
      final source = File(path).readAsStringSync();

      for (final forbiddenImport in [
        'package:flutter_image_compress',
        'package:image_picker',
        'package:image_cropper',
        'package:firebase_',
      ]) {
        expect(source, isNot(contains(forbiddenImport)), reason: path);
      }

      for (final forbiddenType in [
        'XFile',
        'CompressFormat',
        'FlutterImageCompress',
        'ImageSource',
        'CroppedFile',
      ]) {
        expect(
          source,
          isNot(matches(RegExp('\\b$forbiddenType\\b'))),
          reason: path,
        );
      }
    }
  });

  test('processor has no picker, crop, UI, storage, or original result', () {
    final source = File(
      'lib/services/avatar/avatar_image_processor.dart',
    ).readAsStringSync();

    for (final forbiddenText in [
      'AvatarImagePicker',
      'AvatarImageCrop',
      'MediaStorageService',
      'FirebaseStorage',
      'Firestore',
      'Widget',
      'originalPath',
      'path_provider',
    ]) {
      expect(source, isNot(contains(forbiddenText)));
    }
  });

  test('plugin implementation keeps its injected seam plugin-neutral', () {
    final source = File(
      'lib/services/avatar/'
      'flutter_image_compress_avatar_image_compressor_gateway.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'Future<String?> Function(AvatarImageCompressionRequest request)',
      ),
    );
    expect(source, isNot(contains('Function(XFile')));
    expect(source, isNot(contains('Function(CompressFormat')));
  });
}
