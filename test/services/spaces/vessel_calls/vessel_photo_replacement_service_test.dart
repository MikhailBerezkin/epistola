import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/domain/models/vessel_registry.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_storage_gateway.dart';
import 'package:epistola/services/spaces/vessel_calls/vessel_photo_processor.dart';
import 'package:epistola/services/spaces/vessel_calls/vessel_photo_replacement_service.dart';
import 'package:epistola/services/spaces/vessel_calls/vessel_photo_storage_service.dart';
import 'package:epistola/services/spaces/vessel_calls/vessel_registry_firestore_gateway.dart';
import 'package:epistola/services/spaces/vessel_calls/vessel_registry_service.dart';

void main() {
  group('VesselPhotoReplacementService', () {
    test('writes new photo metadata before deleting previous photo', () async {
      final events = <String>[];

      final storageGateway = _RecordingStorageGateway(events: events);

      final storageService = VesselPhotoStorageService(
        storage: storageGateway,
        versionGenerator: () => 2,
      );

      String? savedThumbnailPath;
      String? savedFullPath;
      int? savedVersion;
      String? savedUpdatedBy;

      final registryService = _createRegistryService(
        vesselPhotoWriter:
            ({
              required String documentId,
              required String thumbnailPath,
              required String fullPath,
              required int version,
              required String updatedBy,
            }) async {
              events.add('firestore');

              expect(documentId, 'vessel_001');

              savedThumbnailPath = thumbnailPath;
              savedFullPath = fullPath;
              savedVersion = version;
              savedUpdatedBy = updatedBy;
            },
      );

      final replacementService = VesselPhotoReplacementService(
        storageService: storageService,
        registryService: registryService,
      );

      final images = await _createPreparedImages();

      expect(await images.thumbnailFile.exists(), isTrue);

      expect(await images.fullFile.exists(), isTrue);

      const oldThumbnailPath = 'vessel_photos/imo_9179555/v1/thumb.jpg';

      const oldFullPath = 'vessel_photos/imo_9179555/v1/full.jpg';

      const vessel = VesselRegistryEntry(
        vesselUid: 'vessel_001',
        name: 'TEST VESSEL',
        lineId: 'fit',
        workType: VesselWorkType.container,
        isVerified: true,
        imo: '9179555',
        photoPath: oldThumbnailPath,
        photoThumbPath: oldThumbnailPath,
        photoFullPath: oldFullPath,
        photoVersion: 1,
      );

      final result = await replacementService.replace(
        vessel: vessel,
        images: images,
        updatedBy: 'owner_1',
      );

      const expectedThumbnailPath = 'vessel_photos/imo_9179555/v2/thumb.jpg';

      const expectedFullPath = 'vessel_photos/imo_9179555/v2/full.jpg';

      expect(result.thumbnailPath, expectedThumbnailPath);

      expect(result.fullPath, expectedFullPath);

      expect(result.version, 2);

      expect(savedThumbnailPath, expectedThumbnailPath);

      expect(savedFullPath, expectedFullPath);

      expect(savedVersion, 2);
      expect(savedUpdatedBy, 'owner_1');

      expect(storageGateway.uploadedPaths, <String>[
        expectedThumbnailPath,
        expectedFullPath,
      ]);

      expect(
        storageGateway.deletedPaths,
        containsAll(<String>[oldThumbnailPath, oldFullPath]),
      );

      expect(
        storageGateway.deletedPaths,
        isNot(contains(expectedThumbnailPath)),
      );

      expect(storageGateway.deletedPaths, isNot(contains(expectedFullPath)));

      final firestoreEventIndex = events.indexOf('firestore');

      final oldThumbnailDeleteIndex = events.indexOf(
        'delete:$oldThumbnailPath',
      );

      final oldFullDeleteIndex = events.indexOf('delete:$oldFullPath');

      expect(firestoreEventIndex, greaterThanOrEqualTo(0));

      expect(oldThumbnailDeleteIndex, greaterThan(firestoreEventIndex));

      expect(oldFullDeleteIndex, greaterThan(firestoreEventIndex));

      expect(await images.thumbnailFile.exists(), isFalse);

      expect(await images.fullFile.exists(), isFalse);
    });

    test('deletes newly uploaded photo when Firestore update fails', () async {
      final events = <String>[];

      final storageGateway = _RecordingStorageGateway(events: events);

      final storageService = VesselPhotoStorageService(
        storage: storageGateway,
        versionGenerator: () => 2,
      );

      final registryService = _createRegistryService(
        vesselPhotoWriter:
            ({
              required String documentId,
              required String thumbnailPath,
              required String fullPath,
              required int version,
              required String updatedBy,
            }) async {
              events.add('firestore');

              throw StateError('Simulated Firestore failure.');
            },
      );

      final replacementService = VesselPhotoReplacementService(
        storageService: storageService,
        registryService: registryService,
      );

      final images = await _createPreparedImages();

      const oldThumbnailPath = 'vessel_photos/imo_9179555/v1/thumb.jpg';

      const oldFullPath = 'vessel_photos/imo_9179555/v1/full.jpg';

      const vessel = VesselRegistryEntry(
        vesselUid: 'vessel_001',
        name: 'TEST VESSEL',
        lineId: 'fit',
        workType: VesselWorkType.container,
        isVerified: true,
        imo: '9179555',
        photoPath: oldThumbnailPath,
        photoThumbPath: oldThumbnailPath,
        photoFullPath: oldFullPath,
        photoVersion: 1,
      );

      await expectLater(
        replacementService.replace(
          vessel: vessel,
          images: images,
          updatedBy: 'owner_1',
        ),
        throwsA(isA<StateError>()),
      );

      const newThumbnailPath = 'vessel_photos/imo_9179555/v2/thumb.jpg';

      const newFullPath = 'vessel_photos/imo_9179555/v2/full.jpg';

      expect(storageGateway.uploadedPaths, <String>[
        newThumbnailPath,
        newFullPath,
      ]);

      expect(
        storageGateway.deletedPaths,
        containsAll(<String>[newThumbnailPath, newFullPath]),
      );

      expect(storageGateway.deletedPaths, isNot(contains(oldThumbnailPath)));

      expect(storageGateway.deletedPaths, isNot(contains(oldFullPath)));
    });

    test('cleans prepared local files when replacement fails', () async {
      final storageGateway = _RecordingStorageGateway(events: <String>[]);

      final storageService = VesselPhotoStorageService(
        storage: storageGateway,
        versionGenerator: () => 3,
      );

      final registryService = _createRegistryService(
        vesselPhotoWriter:
            ({
              required String documentId,
              required String thumbnailPath,
              required String fullPath,
              required int version,
              required String updatedBy,
            }) async {
              throw StateError('Simulated Firestore failure.');
            },
      );

      final replacementService = VesselPhotoReplacementService(
        storageService: storageService,
        registryService: registryService,
      );

      final images = await _createPreparedImages();

      expect(await images.thumbnailFile.exists(), isTrue);

      expect(await images.fullFile.exists(), isTrue);

      const vessel = VesselRegistryEntry(
        vesselUid: 'vessel_001',
        name: 'TEST VESSEL',
        lineId: 'fit',
        workType: VesselWorkType.container,
        isVerified: true,
        imo: '9179555',
      );

      await expectLater(
        replacementService.replace(
          vessel: vessel,
          images: images,
          updatedBy: 'brigadier_1',
        ),
        throwsA(isA<StateError>()),
      );

      expect(await images.thumbnailFile.exists(), isFalse);

      expect(await images.fullFile.exists(), isFalse);
    });
  });
}

VesselRegistryService _createRegistryService({
  required VesselRegistryPhotoWriter vesselPhotoWriter,
}) {
  return VesselRegistryService(
    gateway: VesselRegistryFirestoreGateway(
      lineReader: () async => const <VesselRegistryDocument>[],
      vesselReader: () async => const <VesselRegistryDocument>[],
      lineWriter:
          ({
            required String documentId,
            required Map<String, dynamic> data,
          }) async {},
      vesselWriter:
          ({
            required String documentId,
            required Map<String, dynamic> data,
          }) async {},
      vesselPhotoWriter: vesselPhotoWriter,
    ),
  );
}

Future<PreparedVesselPhotoImages> _createPreparedImages() async {
  final sourceDirectory = await Directory.systemTemp.createTemp(
    'epistola_vessel_photo_test_source_',
  );

  addTearDown(() async {
    if (await sourceDirectory.exists()) {
      await sourceDirectory.delete(recursive: true);
    }
  });

  final sourceFile = File(
    '${sourceDirectory.path}'
    '${Platform.pathSeparator}'
    'source.jpg',
  );

  await sourceFile.writeAsBytes(<int>[1, 2, 3, 4]);

  final processor = VesselPhotoProcessor(
    compressor: _FakeImageCompressorGateway(),
    probe: (path) async {
      if (path.contains('thumbnail_')) {
        return const VesselPhotoDimensions(width: 640, height: 427);
      }

      return const VesselPhotoDimensions(width: 1200, height: 800);
    },
  );

  return processor.process(sourceFile.path);
}

final class _FakeImageCompressorGateway
    implements AvatarImageCompressorGateway {
  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    final outputFile = File(request.targetPath);

    await outputFile.writeAsBytes(List<int>.filled(128, request.quality));

    return AvatarCompressedImage(path: outputFile.path);
  }
}

final class _RecordingStorageGateway implements AvatarStorageGateway {
  _RecordingStorageGateway({required this.events});

  final List<String> events;

  final List<String> uploadedPaths = <String>[];
  final List<String> deletedPaths = <String>[];

  @override
  String get providerName => 'test';

  @override
  Future<MediaAsset> uploadFile({
    required File file,
    required String path,
    required String type,
    required String ownerType,
    required String ownerId,
    required String mimeType,
    required int version,
  }) async {
    uploadedPaths.add(path);
    events.add('upload:$path');

    return MediaAsset(
      id: path,
      provider: providerName,
      path: path,
      type: type,
      ownerType: ownerType,
      ownerId: ownerId,
      mimeType: mimeType,
      sizeBytes: await file.length(),
      version: version,
    );
  }

  @override
  Future<void> deleteFile(String path) async {
    deletedPaths.add(path);
    events.add('delete:$path');
  }
}
