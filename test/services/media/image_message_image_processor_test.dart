import 'dart:io';

import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/media/image_message_image_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageMessageImageProcessor', () {
    late Directory testDirectory;
    late File sourceFile;

    setUp(() async {
      testDirectory = await Directory.systemTemp.createTemp(
        'epistola_image_message_processor_test_',
      );

      sourceFile = File(
        '${testDirectory.path}${Platform.pathSeparator}source.jpg',
      );

      await sourceFile.writeAsBytes(List<int>.filled(32, 1), flush: true);
    });

    tearDown(() async {
      if (await testDirectory.exists()) {
        await testDirectory.delete(recursive: true);
      }
    });

    test('prepares landscape thumbnail and full variants', () async {
      final dimensionsByPath = <String, ImageMessageImageDimensions>{
        sourceFile.path: const ImageMessageImageDimensions(
          width: 4000,
          height: 3000,
        ),
      };

      final compressor = _FakeCompressor(
        dimensionsByPath: dimensionsByPath,
        sizeForRequest: (request) {
          return request.targetPath.contains('thumbnail_')
              ? 24 * 1024
              : 280 * 1024;
        },
      );

      final processor = ImageMessageImageProcessor(
        probe: _FakeProbe(dimensionsByPath).call,
        compressor: compressor,
      );

      final result = await processor.process(sourceFile.path);

      expect(compressor.requests, hasLength(2));

      final thumbnailRequest = compressor.requests[0];
      expect(thumbnailRequest.width, 480);
      expect(thumbnailRequest.height, 360);
      expect(thumbnailRequest.quality, 78);
      expect(thumbnailRequest.keepExif, isFalse);
      expect(thumbnailRequest.autoCorrectionAngle, isTrue);

      final fullRequest = compressor.requests[1];
      expect(fullRequest.width, 1920);
      expect(fullRequest.height, 1440);
      expect(fullRequest.quality, 86);
      expect(fullRequest.keepExif, isFalse);
      expect(fullRequest.autoCorrectionAngle, isTrue);

      expect(result.thumbnailWidth, 480);
      expect(result.thumbnailHeight, 360);
      expect(result.fullWidth, 1920);
      expect(result.fullHeight, 1440);
      expect(result.thumbnailSizeBytes, 24 * 1024);
      expect(result.fullSizeBytes, 280 * 1024);

      expect(await result.thumbnailFile.exists(), isTrue);
      expect(await result.fullFile.exists(), isTrue);
      expect(await sourceFile.exists(), isTrue);

      await result.cleanup();
      await result.cleanup();

      expect(await result.thumbnailFile.exists(), isFalse);
      expect(await result.fullFile.exists(), isFalse);
      expect(await sourceFile.exists(), isTrue);
    });

    test('does not upscale a small image', () async {
      final dimensionsByPath = <String, ImageMessageImageDimensions>{
        sourceFile.path: const ImageMessageImageDimensions(
          width: 320,
          height: 240,
        ),
      };

      final compressor = _FakeCompressor(
        dimensionsByPath: dimensionsByPath,
        sizeForRequest: (_) => 20 * 1024,
      );

      final processor = ImageMessageImageProcessor(
        probe: _FakeProbe(dimensionsByPath).call,
        compressor: compressor,
      );

      final result = await processor.process(sourceFile.path);

      expect(compressor.requests, hasLength(2));

      for (final request in compressor.requests) {
        expect(request.width, 320);
        expect(request.height, 240);
      }

      expect(result.thumbnailWidth, 320);
      expect(result.thumbnailHeight, 240);
      expect(result.fullWidth, 320);
      expect(result.fullHeight, 240);

      await result.cleanup();
    });

    test('accepts dimensions rotated by EXIF correction', () async {
      final dimensionsByPath = <String, ImageMessageImageDimensions>{
        sourceFile.path: const ImageMessageImageDimensions(
          width: 4000,
          height: 3000,
        ),
      };

      final compressor = _FakeCompressor(
        dimensionsByPath: dimensionsByPath,
        sizeForRequest: (request) {
          return request.targetPath.contains('thumbnail_')
              ? 24 * 1024
              : 280 * 1024;
        },
        dimensionsForRequest: (request) {
          return ImageMessageImageDimensions(
            width: request.height,
            height: request.width,
          );
        },
      );

      final processor = ImageMessageImageProcessor(
        probe: _FakeProbe(dimensionsByPath).call,
        compressor: compressor,
      );

      final result = await processor.process(sourceFile.path);

      expect(result.thumbnailWidth, 360);
      expect(result.thumbnailHeight, 480);
      expect(result.fullWidth, 1440);
      expect(result.fullHeight, 1920);

      await result.cleanup();
    });

    test('retries full compression to reach the target size', () async {
      final dimensionsByPath = <String, ImageMessageImageDimensions>{
        sourceFile.path: const ImageMessageImageDimensions(
          width: 2400,
          height: 1600,
        ),
      };

      var fullAttempt = 0;

      final compressor = _FakeCompressor(
        dimensionsByPath: dimensionsByPath,
        sizeForRequest: (request) {
          if (request.targetPath.contains('thumbnail_')) {
            return 24 * 1024;
          }

          fullAttempt += 1;

          return fullAttempt == 1 ? 700 * 1024 : 450 * 1024;
        },
      );

      final processor = ImageMessageImageProcessor(
        probe: _FakeProbe(dimensionsByPath).call,
        compressor: compressor,
      );

      final result = await processor.process(sourceFile.path);

      final fullRequests = compressor.requests
          .where((request) => request.targetPath.contains('full_'))
          .toList();

      expect(fullRequests.map((request) => request.quality), [86, 80]);

      expect(await File(fullRequests.first.targetPath).exists(), isFalse);

      expect(result.fullPath, fullRequests.last.targetPath);
      expect(result.fullSizeBytes, 450 * 1024);

      await result.cleanup();
    });

    test('fails when every thumbnail exceeds its hard limit', () async {
      final dimensionsByPath = <String, ImageMessageImageDimensions>{
        sourceFile.path: const ImageMessageImageDimensions(
          width: 1600,
          height: 1200,
        ),
      };

      final compressor = _FakeCompressor(
        dimensionsByPath: dimensionsByPath,
        sizeForRequest: (request) {
          return request.targetPath.contains('thumbnail_')
              ? (128 * 1024) + 1
              : 280 * 1024;
        },
      );

      final processor = ImageMessageImageProcessor(
        probe: _FakeProbe(dimensionsByPath).call,
        compressor: compressor,
      );

      final result = processor.process(sourceFile.path);

      await expectLater(
        result,
        throwsA(
          isA<ImageMessageImageHardLimitExceededException>()
              .having(
                (error) => error.variant,
                'variant',
                ImageMessageImageVariant.thumbnail,
              )
              .having(
                (error) => error.maximumBytes,
                'maximumBytes',
                128 * 1024,
              ),
        ),
      );

      for (final request in compressor.requests) {
        expect(await File(request.targetPath).exists(), isFalse);
      }

      expect(await sourceFile.exists(), isTrue);
    });

    test('rejects an unexpected output path', () async {
      final dimensionsByPath = <String, ImageMessageImageDimensions>{
        sourceFile.path: const ImageMessageImageDimensions(
          width: 800,
          height: 600,
        ),
      };

      final compressor = _UnexpectedPathCompressor(directory: testDirectory);

      final processor = ImageMessageImageProcessor(
        probe: _FakeProbe(dimensionsByPath).call,
        compressor: compressor,
      );

      await expectLater(
        processor.process(sourceFile.path),
        throwsA(
          isA<ImageMessageImageProcessingException>().having(
            (error) => error.code,
            'code',
            'unexpected_output_path',
          ),
        ),
      );

      expect(await sourceFile.exists(), isTrue);
    });
  });
}

final class _FakeProbe {
  const _FakeProbe(this.dimensionsByPath);

  final Map<String, ImageMessageImageDimensions> dimensionsByPath;

  Future<ImageMessageImageDimensions> call(String path) async {
    final dimensions = dimensionsByPath[path];

    if (dimensions == null) {
      throw StateError('Missing fake dimensions for $path');
    }

    return dimensions;
  }
}

typedef _SizeForRequest = int Function(AvatarImageCompressionRequest request);

typedef _DimensionsForRequest =
    ImageMessageImageDimensions Function(AvatarImageCompressionRequest request);

final class _FakeCompressor implements AvatarImageCompressorGateway {
  _FakeCompressor({
    required this.dimensionsByPath,
    required this.sizeForRequest,
    _DimensionsForRequest? dimensionsForRequest,
  }) : dimensionsForRequest = dimensionsForRequest ?? _useRequestedDimensions;

  final Map<String, ImageMessageImageDimensions> dimensionsByPath;
  final _SizeForRequest sizeForRequest;
  final _DimensionsForRequest dimensionsForRequest;
  final List<AvatarImageCompressionRequest> requests = [];

  static ImageMessageImageDimensions _useRequestedDimensions(
    AvatarImageCompressionRequest request,
  ) {
    return ImageMessageImageDimensions(
      width: request.width,
      height: request.height,
    );
  }

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    requests.add(request);

    final outputFile = File(request.targetPath);

    await outputFile.writeAsBytes(
      List<int>.filled(sizeForRequest(request), 0),
      flush: true,
    );

    dimensionsByPath[request.targetPath] = dimensionsForRequest(request);

    return AvatarCompressedImage(path: request.targetPath);
  }
}

final class _UnexpectedPathCompressor implements AvatarImageCompressorGateway {
  const _UnexpectedPathCompressor({required this.directory});

  final Directory directory;

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    final unexpectedFile = File(
      '${directory.path}${Platform.pathSeparator}unexpected.jpg',
    );

    await unexpectedFile.writeAsBytes(
      List<int>.filled(20 * 1024, 0),
      flush: true,
    );

    return AvatarCompressedImage(path: unexpectedFile.path);
  }
}
