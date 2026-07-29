import 'dart:io';

import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_crop_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_crop_service.dart';
import 'package:epistola/services/avatar/avatar_image_picker_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_picker_service.dart';
import 'package:epistola/services/avatar/avatar_image_preparation_service.dart';
import 'package:epistola/services/avatar/avatar_image_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;
  late File gallerySource;
  late File cameraSource;
  late File recoveredSource;
  late File croppedFile;
  final preparedResults = <PreparedAvatarImages>[];

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'epistola_avatar_preparation_test_',
    );
    gallerySource = await _createFile(testDirectory, 'gallery.jpg');
    cameraSource = await _createFile(testDirectory, 'camera.jpg');
    recoveredSource = await _createFile(testDirectory, 'recovered.jpg');
    croppedFile = await _createFile(testDirectory, 'cropped.jpg');
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

  test('prepares an image selected from the gallery in order', () async {
    final events = <String>[];
    final pickerGateway = _FakePickerGateway(
      galleryResult: AvatarPickedImage(path: gallerySource.path),
      events: events,
    );
    final cropGateway = _FakeCropGateway(
      result: AvatarCroppedImage(path: croppedFile.path),
      events: events,
    );
    final processor = AvatarImageProcessor(
      compressor: _FakeCompressor(events: events),
    );
    final service = _createService(
      pickerGateway: pickerGateway,
      cropGateway: cropGateway,
      processor: processor,
      deleteCroppedImage: (path) async {
        events.add('delete:$path');
        await File(path).delete();
      },
    );

    final result = await service.prepareFromGallery();
    preparedResults.add(result!);

    expect(await File(result.thumbnailPath).exists(), isTrue);
    expect(await File(result.fullPath).exists(), isTrue);
    expect(events, [
      'pick:gallery',
      'crop:${gallerySource.path}',
      'process:${croppedFile.path}',
      'delete:${croppedFile.path}',
    ]);
    expect(await gallerySource.exists(), isTrue);
    expect(await croppedFile.exists(), isFalse);
  });

  test('prepares an image captured with the camera', () async {
    final pickerGateway = _FakePickerGateway(
      cameraResult: AvatarPickedImage(path: cameraSource.path),
    );
    final cropGateway = _FakeCropGateway(
      result: AvatarCroppedImage(path: croppedFile.path),
    );
    final processor = AvatarImageProcessor(compressor: _FakeCompressor());
    final service = _createService(
      pickerGateway: pickerGateway,
      cropGateway: cropGateway,
      processor: processor,
    );

    final result = await service.prepareWithCamera();
    preparedResults.add(result!);

    expect(pickerGateway.pickedSources, [AvatarImagePickSource.camera]);
    expect(cropGateway.sourcePaths, [cameraSource.path]);
    expect(await cameraSource.exists(), isTrue);
    expect(await croppedFile.exists(), isFalse);
  });

  test('returns null after picker cancellation without later calls', () async {
    final cropGateway = _FakeCropGateway(
      result: AvatarCroppedImage(path: croppedFile.path),
    );
    final processor = _ThrowingProcessor(StateError('must not process'));
    final deletedPaths = <String>[];
    final service = _createService(
      pickerGateway: _FakePickerGateway(),
      cropGateway: cropGateway,
      processor: processor,
      deleteCroppedImage: (path) async => deletedPaths.add(path),
    );

    expect(await service.prepareFromGallery(), isNull);
    expect(cropGateway.sourcePaths, isEmpty);
    expect(processor.callCount, 0);
    expect(deletedPaths, isEmpty);
  });

  test('returns null after crop cancellation without processing', () async {
    final cropGateway = _FakeCropGateway();
    final processor = _ThrowingProcessor(StateError('must not process'));
    final deletedPaths = <String>[];
    final service = _createService(
      pickerGateway: _FakePickerGateway(
        galleryResult: AvatarPickedImage(path: gallerySource.path),
      ),
      cropGateway: cropGateway,
      processor: processor,
      deleteCroppedImage: (path) async => deletedPaths.add(path),
    );

    expect(await service.prepareFromGallery(), isNull);
    expect(cropGateway.sourcePaths, [gallerySource.path]);
    expect(processor.callCount, 0);
    expect(deletedPaths, isEmpty);
    expect(await gallerySource.exists(), isTrue);
  });

  test('returns null when Android has no lost image data', () async {
    final cropGateway = _FakeCropGateway(
      result: AvatarCroppedImage(path: croppedFile.path),
    );
    final processor = _ThrowingProcessor(StateError('must not process'));
    final service = _createService(
      pickerGateway: _FakePickerGateway(),
      cropGateway: cropGateway,
      processor: processor,
    );

    expect(await service.prepareRecoveredLostImage(), isNull);
    expect(cropGateway.sourcePaths, isEmpty);
    expect(processor.callCount, 0);
  });

  test('prepares a recovered Android lost image', () async {
    final events = <String>[];
    final pickerGateway = _FakePickerGateway(
      recoveredImages: [AvatarPickedImage(path: recoveredSource.path)],
      events: events,
    );
    final cropGateway = _FakeCropGateway(
      result: AvatarCroppedImage(path: croppedFile.path),
      events: events,
    );
    final service = _createService(
      pickerGateway: pickerGateway,
      cropGateway: cropGateway,
      processor: AvatarImageProcessor(
        compressor: _FakeCompressor(events: events),
      ),
      deleteCroppedImage: (path) async {
        events.add('delete:$path');
        await File(path).delete();
      },
    );

    final result = await service.prepareRecoveredLostImage();
    preparedResults.add(result!);

    expect(pickerGateway.recoveryCallCount, 1);
    expect(pickerGateway.pickedSources, isEmpty);
    expect(cropGateway.sourcePaths, [recoveredSource.path]);
    expect(events, [
      'recover',
      'crop:${recoveredSource.path}',
      'process:${croppedFile.path}',
      'delete:${croppedFile.path}',
    ]);
    expect(await recoveredSource.exists(), isTrue);
    expect(await croppedFile.exists(), isFalse);
  });

  test('preserves a picker error and stops the pipeline', () async {
    final error = StateError('picker failed');
    final cropGateway = _FakeCropGateway();
    final processor = _ThrowingProcessor(StateError('must not process'));
    final service = _createService(
      pickerGateway: _FakePickerGateway(pickError: error),
      cropGateway: cropGateway,
      processor: processor,
    );

    await expectLater(service.prepareFromGallery(), throwsA(same(error)));
    expect(cropGateway.sourcePaths, isEmpty);
    expect(processor.callCount, 0);
  });

  test('preserves a lost data recovery error and stops the pipeline', () async {
    const error = AvatarLostDataRecoveryException(
      code: 'recovery_failed',
      message: 'Could not recover the image.',
    );
    final cropGateway = _FakeCropGateway();
    final processor = _ThrowingProcessor(StateError('must not process'));
    final service = _createService(
      pickerGateway: _FakePickerGateway(recoveryError: error),
      cropGateway: cropGateway,
      processor: processor,
    );

    await expectLater(
      service.prepareRecoveredLostImage(),
      throwsA(same(error)),
    );
    expect(cropGateway.sourcePaths, isEmpty);
    expect(processor.callCount, 0);
  });

  test('preserves a crop error and does not process', () async {
    const error = AvatarImageCropException(
      code: 'crop_failed',
      message: 'Could not crop the image.',
    );
    final cropGateway = _FakeCropGateway(error: error);
    final processor = _ThrowingProcessor(StateError('must not process'));
    final service = _createService(
      pickerGateway: _FakePickerGateway(
        galleryResult: AvatarPickedImage(path: gallerySource.path),
      ),
      cropGateway: cropGateway,
      processor: processor,
    );

    await expectLater(service.prepareFromGallery(), throwsA(same(error)));
    expect(processor.callCount, 0);
    expect(await gallerySource.exists(), isTrue);
  });

  test('deletes the cropped file after a processor error', () async {
    final error = StateError('processor failed');
    final processor = _ThrowingProcessor(error);
    final deletedPaths = <String>[];
    final service = _createService(
      pickerGateway: _FakePickerGateway(
        galleryResult: AvatarPickedImage(path: gallerySource.path),
      ),
      cropGateway: _FakeCropGateway(
        result: AvatarCroppedImage(path: croppedFile.path),
      ),
      processor: processor,
      deleteCroppedImage: (path) async {
        deletedPaths.add(path);
        await File(path).delete();
      },
    );

    await expectLater(service.prepareFromGallery(), throwsA(same(error)));
    expect(deletedPaths, [croppedFile.path]);
    expect(await croppedFile.exists(), isFalse);
    expect(await gallerySource.exists(), isTrue);
  });

  test('preserves the processor error when cropped cleanup fails', () async {
    final error = StateError('processor failed');
    final service = _createService(
      pickerGateway: _FakePickerGateway(
        galleryResult: AvatarPickedImage(path: gallerySource.path),
      ),
      cropGateway: _FakeCropGateway(
        result: AvatarCroppedImage(path: croppedFile.path),
      ),
      processor: _ThrowingProcessor(error),
      deleteCroppedImage: (_) async => throw StateError('cleanup failed'),
    );

    await expectLater(service.prepareFromGallery(), throwsA(same(error)));
    expect(await croppedFile.exists(), isTrue);
    expect(await gallerySource.exists(), isTrue);
  });

  test(
    'does not mask a successful result when cropped cleanup fails',
    () async {
      final service = _createService(
        pickerGateway: _FakePickerGateway(
          galleryResult: AvatarPickedImage(path: gallerySource.path),
        ),
        cropGateway: _FakeCropGateway(
          result: AvatarCroppedImage(path: croppedFile.path),
        ),
        processor: AvatarImageProcessor(compressor: _FakeCompressor()),
        deleteCroppedImage: (_) async => throw StateError('cleanup failed'),
      );

      final result = await service.prepareFromGallery();
      preparedResults.add(result!);

      expect(await File(result.thumbnailPath).exists(), isTrue);
      expect(await File(result.fullPath).exists(), isTrue);
      expect(await gallerySource.exists(), isTrue);
    },
  );

  test('never deletes the picked source when crop returns its path', () async {
    final deletedPaths = <String>[];
    final service = _createService(
      pickerGateway: _FakePickerGateway(
        galleryResult: AvatarPickedImage(path: gallerySource.path),
      ),
      cropGateway: _FakeCropGateway(
        result: AvatarCroppedImage(path: gallerySource.path),
      ),
      processor: AvatarImageProcessor(compressor: _FakeCompressor()),
      deleteCroppedImage: (path) async => deletedPaths.add(path),
    );

    final result = await service.prepareFromGallery();
    preparedResults.add(result!);

    expect(deletedPaths, isEmpty);
    expect(await gallerySource.exists(), isTrue);
  });

  test('does not call PreparedAvatarImages.cleanup', () async {
    var preparedCleanupCallCount = 0;
    final processor = AvatarImageProcessor(
      compressor: _FakeCompressor(),
      cleanupInvoker: ({required workingDirectory, required filePaths}) async {
        preparedCleanupCallCount++;

        if (await workingDirectory.exists()) {
          await workingDirectory.delete(recursive: true);
        }

        return true;
      },
    );
    final service = _createService(
      pickerGateway: _FakePickerGateway(
        galleryResult: AvatarPickedImage(path: gallerySource.path),
      ),
      cropGateway: _FakeCropGateway(
        result: AvatarCroppedImage(path: croppedFile.path),
      ),
      processor: processor,
    );

    final result = await service.prepareFromGallery();
    preparedResults.add(result!);

    expect(preparedCleanupCallCount, 0);
    expect(await File(result.thumbnailPath).exists(), isTrue);
    expect(await File(result.fullPath).exists(), isTrue);
  });

  test('public preparation seam remains plugin-neutral', () {
    final source = File(
      'lib/services/avatar/avatar_image_preparation_service.dart',
    ).readAsStringSync();

    for (final forbiddenImport in [
      'package:image_picker',
      'package:image_cropper',
      'package:flutter_image_compress',
      'package:firebase_',
      'FirebaseStorage',
      'Firestore',
      'Widget',
    ]) {
      expect(source, isNot(contains(forbiddenImport)));
    }

    for (final forbiddenType in [
      'ImagePicker',
      'XFile',
      'CroppedFile',
      'ImageSource',
    ]) {
      expect(source, isNot(matches(RegExp('\\b$forbiddenType\\b'))));
    }
  });
}

AvatarImagePreparationService _createService({
  required _FakePickerGateway pickerGateway,
  required _FakeCropGateway cropGateway,
  required AvatarImageProcessor processor,
  AvatarCroppedImageDeleteInvoker? deleteCroppedImage,
}) {
  return AvatarImagePreparationService(
    picker: AvatarImagePickerService(gateway: pickerGateway),
    cropper: AvatarImageCropService(gateway: cropGateway),
    processor: processor,
    deleteCroppedImage: deleteCroppedImage,
  );
}

Future<File> _createFile(Directory directory, String name) {
  return File(
    '${directory.path}${Platform.pathSeparator}$name',
  ).writeAsBytes([1, 2, 3]);
}

final class _FakePickerGateway implements AvatarImagePickerGateway {
  _FakePickerGateway({
    this.galleryResult,
    this.cameraResult,
    this.recoveredImages = const [],
    this.pickError,
    this.recoveryError,
    this.events,
  });

  final AvatarPickedImage? galleryResult;
  final AvatarPickedImage? cameraResult;
  final List<AvatarPickedImage> recoveredImages;
  final Object? pickError;
  final Object? recoveryError;
  final List<String>? events;
  final List<AvatarImagePickSource> pickedSources = [];
  int recoveryCallCount = 0;

  @override
  Future<AvatarPickedImage?> pickImage(AvatarImagePickSource source) async {
    pickedSources.add(source);
    events?.add('pick:${source.name}');

    final error = pickError;

    if (error != null) {
      throw error;
    }

    return switch (source) {
      AvatarImagePickSource.gallery => galleryResult,
      AvatarImagePickSource.camera => cameraResult,
    };
  }

  @override
  Future<List<AvatarPickedImage>> retrieveLostImages() async {
    recoveryCallCount++;
    events?.add('recover');

    final error = recoveryError;

    if (error != null) {
      throw error;
    }

    return recoveredImages;
  }
}

final class _FakeCropGateway implements AvatarImageCropGateway {
  _FakeCropGateway({this.result, this.error, this.events});

  final AvatarCroppedImage? result;
  final Object? error;
  final List<String>? events;
  final List<String> sourcePaths = [];

  @override
  Future<AvatarCroppedImage?> cropSquare(String sourcePath) async {
    sourcePaths.add(sourcePath);
    events?.add('crop:$sourcePath');

    final cropError = error;

    if (cropError != null) {
      throw cropError;
    }

    return result;
  }
}

final class _FakeCompressor implements AvatarImageCompressorGateway {
  _FakeCompressor({this.events});

  final List<String>? events;
  int callCount = 0;

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    if (callCount == 0) {
      events?.add('process:${request.sourcePath}');
    }
    callCount++;

    await File(request.targetPath).writeAsBytes([1, 2, 3]);
    return AvatarCompressedImage(path: request.targetPath);
  }
}

final class _ThrowingProcessor implements AvatarImageProcessor {
  _ThrowingProcessor(this.error);

  final Object error;
  int callCount = 0;

  @override
  Future<PreparedAvatarImages> process(String sourcePath) async {
    callCount++;
    throw error;
  }
}
