import 'dart:async';
import 'dart:io';

import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_pipeline_config.dart';
import 'package:epistola/services/avatar/avatar_image_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sourceDirectory;
  late File sourceFile;
  final successfulResults = <PreparedAvatarImages>[];

  setUp(() async {
    sourceDirectory = await Directory.systemTemp.createTemp(
      'epistola_avatar_processor_test_source_',
    );
    sourceFile = File(
      '${sourceDirectory.path}${Platform.pathSeparator}cropped.jpg',
    );
    await sourceFile.writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    for (final result in successfulResults) {
      await result.cleanup();
    }
    successfulResults.clear();

    if (await sourceDirectory.exists()) {
      await sourceDirectory.delete(recursive: true);
    }
  });

  test('rejects an empty source path before calling the compressor', () {
    final compressor = _FakeAvatarImageCompressor();
    final processor = AvatarImageProcessor(compressor: compressor);

    expect(
      () => processor.process('   '),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.name,
          'name',
          'sourcePath',
        ),
      ),
    );
    expect(compressor.requests, isEmpty);
  });

  test(
    'uses the exact thumbnail and first full compression settings',
    () async {
      final compressor = _FakeAvatarImageCompressor(
        outputSizes: [1024, AvatarImagePipelineConfig.desiredFullSizeBytes],
      );
      final processor = AvatarImageProcessor(compressor: compressor);

      final result = await processor.process(sourceFile.path);
      successfulResults.add(result);

      expect(compressor.requests, hasLength(2));
      final thumbnail = compressor.requests[0];
      expect(thumbnail.sourcePath, sourceFile.path);
      expect(thumbnail.format, AvatarImageFormat.jpeg);
      expect(thumbnail.width, 128);
      expect(thumbnail.height, 128);
      expect(thumbnail.quality, 75);
      expect(thumbnail.keepExif, isFalse);
      expect(thumbnail.autoCorrectionAngle, isTrue);
      expect(thumbnail.rotate, 0);

      final full = compressor.requests[1];
      expect(full.sourcePath, sourceFile.path);
      expect(full.format, AvatarImageFormat.jpeg);
      expect(full.width, 512);
      expect(full.height, 512);
      expect(full.quality, 82);
      expect(full.keepExif, isFalse);
      expect(full.autoCorrectionAngle, isTrue);
      expect(full.rotate, 0);
    },
  );

  test('accepts a full image at 300 KB without recompressing', () async {
    final compressor = _FakeAvatarImageCompressor(
      outputSizes: [1024, AvatarImagePipelineConfig.desiredFullSizeBytes],
    );
    final processor = AvatarImageProcessor(compressor: compressor);

    final result = await processor.process(sourceFile.path);
    successfulResults.add(result);

    expect(compressor.requests, hasLength(2));
    expect(await File(result.thumbnailPath).exists(), isTrue);
    expect(await File(result.fullPath).exists(), isTrue);
  });

  test('retries qualities in order from the same cropped source', () async {
    final qualities = AvatarImagePipelineConfig.full.qualityAttempts;
    final compressor = _FakeAvatarImageCompressor(
      outputSizes: [
        1024,
        ...List.filled(
          qualities.length - 1,
          AvatarImagePipelineConfig.desiredFullSizeBytes + 1,
        ),
        400 * 1024,
      ],
    );
    final processor = AvatarImageProcessor(compressor: compressor);

    final result = await processor.process(sourceFile.path);
    successfulResults.add(result);

    final fullRequests = compressor.requests.skip(1).toList();
    expect(fullRequests.map((request) => request.quality), qualities);
    expect(fullRequests.map((request) => request.sourcePath).toSet(), {
      sourceFile.path,
    });
  });

  test('deletes every rejected full attempt before returning', () async {
    final compressor = _FakeAvatarImageCompressor(
      outputSizes: [
        1024,
        AvatarImagePipelineConfig.desiredFullSizeBytes + 1,
        200 * 1024,
      ],
    );
    final processor = AvatarImageProcessor(compressor: compressor);

    final result = await processor.process(sourceFile.path);
    successfulResults.add(result);

    final rejectedPath = compressor.requests[1].targetPath;
    expect(await File(rejectedPath).exists(), isFalse);
    expect(result.fullPath, compressor.requests[2].targetPath);
    expect(await File(result.fullPath).exists(), isTrue);
  });

  test(
    'accepts the final attempt between the desired and hard limits',
    () async {
      final attemptCount =
          AvatarImagePipelineConfig.full.qualityAttempts.length;
      final compressor = _FakeAvatarImageCompressor(
        outputSizes: [
          1024,
          ...List.filled(
            attemptCount - 1,
            AvatarImagePipelineConfig.desiredFullSizeBytes + 1,
          ),
          400 * 1024,
        ],
      );
      final processor = AvatarImageProcessor(compressor: compressor);

      final result = await processor.process(sourceFile.path);
      successfulResults.add(result);

      expect(compressor.requests, hasLength(attemptCount + 1));
      expect(await File(result.fullPath).length(), 400 * 1024);
    },
  );

  test('throws a dedicated hard-limit error and removes all outputs', () async {
    final attemptCount = AvatarImagePipelineConfig.full.qualityAttempts.length;
    final compressor = _FakeAvatarImageCompressor(
      outputSizes: [
        1024,
        ...List.filled(
          attemptCount,
          AvatarImagePipelineConfig.hardFullSizeBytes + 1,
        ),
      ],
    );
    final processor = AvatarImageProcessor(compressor: compressor);

    await expectLater(
      processor.process(sourceFile.path),
      throwsA(
        isA<AvatarImageHardLimitExceededException>()
            .having(
              (error) => error.actualBytes,
              'actualBytes',
              AvatarImagePipelineConfig.hardFullSizeBytes + 1,
            )
            .having(
              (error) => error.maximumBytes,
              'maximumBytes',
              AvatarImagePipelineConfig.hardFullSizeBytes,
            ),
      ),
    );

    final workingDirectory = File(compressor.requests.first.targetPath).parent;
    expect(await workingDirectory.exists(), isFalse);
    expect(await sourceFile.exists(), isTrue);
  });

  test('treats null compressor output as a typed processing error', () async {
    final compressor = _FakeAvatarImageCompressor(returnNullAt: {0});
    final processor = AvatarImageProcessor(compressor: compressor);

    await expectLater(
      processor.process(sourceFile.path),
      throwsA(
        isA<AvatarImageProcessorException>().having(
          (error) => error.code,
          'code',
          'compression_output_missing',
        ),
      ),
    );
    expect(
      await File(compressor.requests.single.targetPath).parent.exists(),
      isFalse,
    );
  });

  test('treats an empty compressor output path as a typed error', () async {
    final compressor = _FakeAvatarImageCompressor(returnEmptyAt: {0});
    final processor = AvatarImageProcessor(compressor: compressor);

    await expectLater(
      processor.process(sourceFile.path),
      throwsA(isA<AvatarImageProcessorException>()),
    );
    expect(
      await File(compressor.requests.single.targetPath).parent.exists(),
      isFalse,
    );
  });

  test('treats a missing compressor output file as a typed error', () async {
    final compressor = _FakeAvatarImageCompressor(skipFileAt: {0});
    final processor = AvatarImageProcessor(compressor: compressor);

    await expectLater(
      processor.process(sourceFile.path),
      throwsA(
        isA<AvatarImageProcessorException>().having(
          (error) => error.code,
          'code',
          'compression_output_missing',
        ),
      ),
    );
    expect(
      await File(compressor.requests.single.targetPath).parent.exists(),
      isFalse,
    );
  });

  test('cleans processor files without masking the processing error', () async {
    final processingError = StateError('compressor failed');
    final compressor = _FakeAvatarImageCompressor(
      errorAt: {1: processingError},
    );
    final processor = AvatarImageProcessor(
      compressor: compressor,
      cleanupInvoker: ({required workingDirectory, required filePaths}) async {
        if (await workingDirectory.exists()) {
          await workingDirectory.delete(recursive: true);
        }

        throw StateError('cleanup failed');
      },
    );

    await expectLater(
      processor.process(sourceFile.path),
      throwsA(same(processingError)),
    );

    final workingDirectory = File(compressor.requests.first.targetPath).parent;
    expect(await workingDirectory.exists(), isFalse);
    expect(await sourceFile.exists(), isTrue);
  });

  test('returns only prepared images with idempotent owned cleanup', () async {
    final compressor = _FakeAvatarImageCompressor();
    final processor = AvatarImageProcessor(compressor: compressor);

    final result = await processor.process(sourceFile.path);
    final workingDirectory = File(result.thumbnailPath).parent;

    expect(await File(result.thumbnailPath).exists(), isTrue);
    expect(await File(result.fullPath).exists(), isTrue);
    expect(await workingDirectory.exists(), isTrue);

    await result.cleanup();
    await result.cleanup();

    expect(await workingDirectory.exists(), isFalse);
    expect(await sourceFile.exists(), isTrue);
  });

  test('retries cleanup when the working directory remains', () async {
    var cleanupCallCount = 0;
    final processor = AvatarImageProcessor(
      compressor: _FakeAvatarImageCompressor(),
      cleanupInvoker: ({required workingDirectory, required filePaths}) async {
        cleanupCallCount++;

        if (cleanupCallCount == 1) {
          return false;
        }

        if (await workingDirectory.exists()) {
          await workingDirectory.delete(recursive: true);
        }

        return !await workingDirectory.exists();
      },
    );

    final result = await processor.process(sourceFile.path);
    successfulResults.add(result);
    final workingDirectory = File(result.thumbnailPath).parent;

    await result.cleanup();

    expect(cleanupCallCount, 1);
    expect(await workingDirectory.exists(), isTrue);

    await result.cleanup();

    expect(cleanupCallCount, 2);
    expect(await workingDirectory.exists(), isFalse);
    expect(await sourceFile.exists(), isTrue);

    await result.cleanup();
    expect(cleanupCallCount, 2);
  });

  test('coalesces simultaneous cleanup calls', () async {
    var cleanupCallCount = 0;
    final allowCleanup = Completer<void>();
    final processor = AvatarImageProcessor(
      compressor: _FakeAvatarImageCompressor(),
      cleanupInvoker: ({required workingDirectory, required filePaths}) async {
        cleanupCallCount++;
        await allowCleanup.future;

        if (await workingDirectory.exists()) {
          await workingDirectory.delete(recursive: true);
        }

        return !await workingDirectory.exists();
      },
    );

    final result = await processor.process(sourceFile.path);
    successfulResults.add(result);
    final workingDirectory = File(result.thumbnailPath).parent;
    final firstCleanup = result.cleanup();
    final secondCleanup = result.cleanup();

    try {
      expect(identical(firstCleanup, secondCleanup), isTrue);
      expect(cleanupCallCount, 1);
    } finally {
      allowCleanup.complete();
    }

    await Future.wait([firstCleanup, secondCleanup]);

    expect(cleanupCallCount, 1);
    expect(await workingDirectory.exists(), isFalse);
    expect(await sourceFile.exists(), isTrue);
  });

  test('uses a separate temporary working directory per operation', () async {
    final first = await AvatarImageProcessor(
      compressor: _FakeAvatarImageCompressor(),
    ).process(sourceFile.path);
    successfulResults.add(first);
    final second = await AvatarImageProcessor(
      compressor: _FakeAvatarImageCompressor(),
    ).process(sourceFile.path);
    successfulResults.add(second);

    expect(
      File(first.thumbnailPath).parent.path,
      isNot(File(second.thumbnailPath).parent.path),
    );
  });
}

final class _FakeAvatarImageCompressor implements AvatarImageCompressorGateway {
  _FakeAvatarImageCompressor({
    this.outputSizes = const [1024, 1024],
    this.returnNullAt = const {},
    this.returnEmptyAt = const {},
    this.skipFileAt = const {},
    this.errorAt = const {},
  });

  final List<int> outputSizes;
  final Set<int> returnNullAt;
  final Set<int> returnEmptyAt;
  final Set<int> skipFileAt;
  final Map<int, Object> errorAt;
  final List<AvatarImageCompressionRequest> requests = [];

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    final callIndex = requests.length;
    requests.add(request);

    final error = errorAt[callIndex];

    if (error != null) {
      throw error;
    }

    if (returnNullAt.contains(callIndex)) {
      return null;
    }

    if (returnEmptyAt.contains(callIndex)) {
      return const AvatarCompressedImage(path: '   ');
    }

    if (!skipFileAt.contains(callIndex)) {
      final output = await File(request.targetPath).open(mode: FileMode.write);
      await output.truncate(
        outputSizes[callIndex.clamp(0, outputSizes.length - 1)],
      );
      await output.close();
    }

    return AvatarCompressedImage(path: request.targetPath);
  }
}
