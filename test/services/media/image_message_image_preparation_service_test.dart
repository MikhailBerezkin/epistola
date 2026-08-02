import 'dart:io';

import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_picker_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_picker_service.dart';
import 'package:epistola/services/media/image_message_image_preparation_service.dart';
import 'package:epistola/services/media/image_message_image_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageMessageImagePreparationService', () {
    late Directory testDirectory;
    late File gallerySource;
    late File cameraSource;
    late File recoveredSource;

    final preparedResults = <PreparedImageMessageImages>[];

    setUp(() async {
      testDirectory = await Directory.systemTemp.createTemp(
        'epistola_image_message_preparation_test_',
      );

      gallerySource = await _createSourceFile(
        directory: testDirectory,
        name: 'gallery.jpg',
      );

      cameraSource = await _createSourceFile(
        directory: testDirectory,
        name: 'camera.jpg',
      );

      recoveredSource = await _createSourceFile(
        directory: testDirectory,
        name: 'recovered.jpg',
      );
    });

    tearDown(() async {
      for (final result in preparedResults) {
        await result.cleanup();
      }

      preparedResults.clear();

      if (await testDirectory.exists()) {
        await testDirectory.delete(recursive: true);
      }
    });

    test('prepares an image selected from the gallery', () async {
      final pickerGateway = _FakePickerGateway(
        galleryResult: AvatarPickedImage(path: gallerySource.path),
      );

      final compressor = _FakeCompressor();

      final service = _createService(
        pickerGateway: pickerGateway,
        compressor: compressor,
        sourceDimensions: {
          gallerySource.path: const ImageMessageImageDimensions(
            width: 1600,
            height: 1200,
          ),
        },
      );

      final result = await service.prepareFromGallery();

      expect(result, isNotNull);
      preparedResults.add(result!);

      expect(pickerGateway.pickedSources, [AvatarImagePickSource.gallery]);

      expect(compressor.sourcePaths, [gallerySource.path, gallerySource.path]);

      expect(result.thumbnailWidth, 480);
      expect(result.thumbnailHeight, 360);
      expect(result.fullWidth, 1600);
      expect(result.fullHeight, 1200);

      expect(await result.thumbnailFile.exists(), isTrue);
      expect(await result.fullFile.exists(), isTrue);
      expect(await gallerySource.exists(), isTrue);
    });

    test('prepares an image captured with the camera', () async {
      final pickerGateway = _FakePickerGateway(
        cameraResult: AvatarPickedImage(path: cameraSource.path),
      );

      final service = _createService(
        pickerGateway: pickerGateway,
        compressor: _FakeCompressor(),
        sourceDimensions: {
          cameraSource.path: const ImageMessageImageDimensions(
            width: 1200,
            height: 1600,
          ),
        },
      );

      final result = await service.prepareWithCamera();

      expect(result, isNotNull);
      preparedResults.add(result!);

      expect(pickerGateway.pickedSources, [AvatarImagePickSource.camera]);

      expect(result.thumbnailWidth, 360);
      expect(result.thumbnailHeight, 480);
      expect(result.fullWidth, 1200);
      expect(result.fullHeight, 1600);

      expect(await cameraSource.exists(), isTrue);
    });

    test('prepares the first recovered Android lost image', () async {
      final pickerGateway = _FakePickerGateway(
        recoveredImages: [
          AvatarPickedImage(path: recoveredSource.path),
          AvatarPickedImage(path: gallerySource.path),
        ],
      );

      final compressor = _FakeCompressor();

      final service = _createService(
        pickerGateway: pickerGateway,
        compressor: compressor,
        sourceDimensions: {
          recoveredSource.path: const ImageMessageImageDimensions(
            width: 1000,
            height: 750,
          ),
        },
      );

      final result = await service.prepareRecoveredLostImage();

      expect(result, isNotNull);
      preparedResults.add(result!);

      expect(pickerGateway.recoveryCallCount, 1);

      expect(compressor.sourcePaths, [
        recoveredSource.path,
        recoveredSource.path,
      ]);

      expect(result.fullWidth, 1000);
      expect(result.fullHeight, 750);
    });

    test('returns null after gallery cancellation', () async {
      final pickerGateway = _FakePickerGateway();
      final compressor = _FakeCompressor();

      final service = _createService(
        pickerGateway: pickerGateway,
        compressor: compressor,
        sourceDimensions: const {},
      );

      final result = await service.prepareFromGallery();

      expect(result, isNull);

      expect(pickerGateway.pickedSources, [AvatarImagePickSource.gallery]);

      expect(compressor.sourcePaths, isEmpty);
    });
    test('returns null when image editing is cancelled', () async {
      final pickerGateway = _FakePickerGateway(
        galleryResult: AvatarPickedImage(path: gallerySource.path),
      );

      final compressor = _FakeCompressor();
      final cropRequests = <String>[];

      final service = _createService(
        pickerGateway: pickerGateway,
        compressor: compressor,
        sourceDimensions: {
          gallerySource.path: const ImageMessageImageDimensions(
            width: 1600,
            height: 1200,
          ),
        },
        cropImage: (sourcePath) async {
          cropRequests.add(sourcePath);
          return null;
        },
      );

      final result = await service.prepareFromGallery();

      expect(result, isNull);

      expect(cropRequests, [gallerySource.path]);

      expect(compressor.sourcePaths, isEmpty);
      expect(await gallerySource.exists(), isTrue);
    });

    test('returns null when Android has no lost image', () async {
      final pickerGateway = _FakePickerGateway();
      final compressor = _FakeCompressor();

      final service = _createService(
        pickerGateway: pickerGateway,
        compressor: compressor,
        sourceDimensions: const {},
      );

      final result = await service.prepareRecoveredLostImage();

      expect(result, isNull);
      expect(pickerGateway.recoveryCallCount, 1);
      expect(compressor.sourcePaths, isEmpty);
    });
  });
}

ImageMessageImagePreparationService _createService({
  required AvatarImagePickerGateway pickerGateway,
  required AvatarImageCompressorGateway compressor,
  required Map<String, ImageMessageImageDimensions> sourceDimensions,
  ImageMessageImageCropper? cropImage,
}) {
  final dimensionsByPath = <String, ImageMessageImageDimensions>{
    ...sourceDimensions,
  };

  final processor = ImageMessageImageProcessor(
    compressor: compressor,
    probe: (path) async {
      final dimensions = dimensionsByPath[path];

      if (dimensions == null) {
        throw StateError('Missing fake dimensions for $path');
      }

      return dimensions;
    },
  );

  if (compressor is _FakeCompressor) {
    compressor.onOutputCreated =
        ({required String path, required int width, required int height}) {
          dimensionsByPath[path] = ImageMessageImageDimensions(
            width: width,
            height: height,
          );
        };
  }

  return ImageMessageImagePreparationService(
    picker: AvatarImagePickerService(gateway: pickerGateway),
    processor: processor,
    cropImage: cropImage ?? (sourcePath) async => sourcePath,
  );
}

Future<File> _createSourceFile({
  required Directory directory,
  required String name,
}) {
  final file = File('${directory.path}${Platform.pathSeparator}$name');

  return file.writeAsBytes(List<int>.filled(32, 1), flush: true);
}

final class _FakePickerGateway implements AvatarImagePickerGateway {
  _FakePickerGateway({
    this.galleryResult,
    this.cameraResult,
    this.recoveredImages = const [],
  });

  final AvatarPickedImage? galleryResult;
  final AvatarPickedImage? cameraResult;
  final List<AvatarPickedImage> recoveredImages;

  final List<AvatarImagePickSource> pickedSources = [];

  int recoveryCallCount = 0;

  @override
  Future<AvatarPickedImage?> pickImage(AvatarImagePickSource source) async {
    pickedSources.add(source);

    return switch (source) {
      AvatarImagePickSource.gallery => galleryResult,
      AvatarImagePickSource.camera => cameraResult,
    };
  }

  @override
  Future<List<AvatarPickedImage>> retrieveLostImages() async {
    recoveryCallCount += 1;

    return recoveredImages;
  }
}

typedef _OutputCreatedCallback =
    void Function({
      required String path,
      required int width,
      required int height,
    });

final class _FakeCompressor implements AvatarImageCompressorGateway {
  final List<String> sourcePaths = [];

  _OutputCreatedCallback? onOutputCreated;

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    sourcePaths.add(request.sourcePath);

    final outputFile = File(request.targetPath);

    final sizeBytes = request.targetPath.contains('thumbnail_')
        ? 24 * 1024
        : 280 * 1024;

    await outputFile.writeAsBytes(List<int>.filled(sizeBytes, 0), flush: true);

    onOutputCreated?.call(
      path: request.targetPath,
      width: request.width,
      height: request.height,
    );

    return AvatarCompressedImage(path: request.targetPath);
  }
}
