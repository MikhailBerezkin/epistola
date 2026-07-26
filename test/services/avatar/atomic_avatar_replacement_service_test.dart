import 'dart:io';

import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/domain/models/user_avatar.dart';
import 'package:epistola/services/avatar/atomic_avatar_replacement_service.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_processor.dart';
import 'package:epistola/services/avatar/avatar_storage_gateway.dart';
import 'package:epistola/services/avatar/avatar_storage_upload_service.dart';
import 'package:epistola/services/avatar/user_avatar_metadata_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'epistola_atomic_avatar_replacement_test_',
    );
  });

  tearDown(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  Future<PreparedAvatarImages> prepareImages({
    required List<String> events,
    bool cleanupThrows = false,
  }) async {
    final source = File(
      '${testDirectory.path}${Platform.pathSeparator}source.jpg',
    );
    await source.writeAsBytes(List.filled(24, 1));
    final processor = AvatarImageProcessor(
      compressor: _FakeCompressor(),
      cleanupInvoker: ({required workingDirectory, required filePaths}) async {
        events.add('local-cleanup');

        if (cleanupThrows) {
          throw StateError('local cleanup failed');
        }

        if (await workingDirectory.exists()) {
          await workingDirectory.delete(recursive: true);
        }

        return true;
      },
    );
    return processor.process(source.path);
  }

  AtomicAvatarReplacementService createService({
    required _FakeMediaStorageProvider provider,
    required UserAvatarMetadataGateway metadata,
    required int version,
  }) {
    return AtomicAvatarReplacementService(
      storage: AvatarStorageUploadService(provider: provider),
      metadata: metadata,
      versionGenerator: () => version,
    );
  }

  test(
    'orders upload, metadata switch, old delete, and local cleanup',
    () async {
      final events = <String>[];
      final images = await prepareImages(events: events);
      final provider = _FakeMediaStorageProvider(events: events);
      final previous = _avatar(uid: 'user-1', version: 7);
      final metadata = _FakeMetadataGateway(
        events: events,
        previousAvatar: previous,
      );
      final service = createService(
        provider: provider,
        metadata: metadata,
        version: 8,
      );

      final result = await service.replace(uid: 'user-1', images: images);

      expect(result.version, 8);
      expect(events, [
        'upload:user_avatars/user-1/v8/thumb.jpg',
        'upload:user_avatars/user-1/v8/full.jpg',
        'metadata:8',
        'delete:user_avatars/user-1/v7/thumb.jpg',
        'delete:user_avatars/user-1/v7/full.jpg',
        'local-cleanup',
      ]);
      expect(metadata.lastAvatar, same(result));
    },
  );

  test('first avatar performs no old-version delete', () async {
    final events = <String>[];
    final images = await prepareImages(events: events);
    final provider = _FakeMediaStorageProvider(events: events);
    final metadata = _FakeMetadataGateway(events: events);
    final service = createService(
      provider: provider,
      metadata: metadata,
      version: 1,
    );

    await service.replace(uid: 'user-1', images: images);

    expect(provider.deletedPaths, isEmpty);
    expect(events.last, 'local-cleanup');
  });

  test(
    'upload failure skips Firestore and never deletes the old avatar',
    () async {
      final events = <String>[];
      final images = await prepareImages(events: events);
      final uploadError = StateError('full upload failed');
      final provider = _FakeMediaStorageProvider(
        events: events,
        uploadErrors: {'user_avatars/user-1/v8/full.jpg': uploadError},
      );
      final metadata = _FakeMetadataGateway(
        events: events,
        previousAvatar: _avatar(uid: 'user-1', version: 7),
      );
      final service = createService(
        provider: provider,
        metadata: metadata,
        version: 8,
      );

      await expectLater(
        service.replace(uid: 'user-1', images: images),
        throwsA(same(uploadError)),
      );

      expect(metadata.callCount, 0);
      expect(provider.deletedPaths, [
        'user_avatars/user-1/v8/thumb.jpg',
        'user_avatars/user-1/v8/full.jpg',
      ]);
      expect(
        provider.deletedPaths,
        isNot(contains('user_avatars/user-1/v7/full.jpg')),
      );
      expect(events.last, 'local-cleanup');
    },
  );

  test('Firestore failure deletes only the newly uploaded version', () async {
    final events = <String>[];
    final images = await prepareImages(events: events);
    final firestoreError = StateError('Firestore failed');
    final provider = _FakeMediaStorageProvider(events: events);
    final metadata = _FakeMetadataGateway(
      events: events,
      error: firestoreError,
    );
    final service = createService(
      provider: provider,
      metadata: metadata,
      version: 8,
    );

    await expectLater(
      service.replace(uid: 'user-1', images: images),
      throwsA(same(firestoreError)),
    );

    expect(provider.deletedPaths, [
      'user_avatars/user-1/v8/thumb.jpg',
      'user_avatars/user-1/v8/full.jpg',
    ]);
    expect(events.last, 'local-cleanup');
  });

  test(
    'remote and local cleanup failures do not mask a Firestore error',
    () async {
      final events = <String>[];
      final images = await prepareImages(events: events, cleanupThrows: true);
      final firestoreError = StateError('Firestore failed');
      final provider = _FakeMediaStorageProvider(
        events: events,
        deleteErrors: {
          'user_avatars/user-1/v8/thumb.jpg': StateError(
            'thumb cleanup failed',
          ),
          'user_avatars/user-1/v8/full.jpg': StateError('full cleanup failed'),
        },
      );
      final service = createService(
        provider: provider,
        metadata: _FakeMetadataGateway(events: events, error: firestoreError),
        version: 8,
      );

      await expectLater(
        service.replace(uid: 'user-1', images: images),
        throwsA(same(firestoreError)),
      );

      expect(events.where((event) => event == 'local-cleanup'), hasLength(1));
    },
  );

  test('old-version delete failure keeps the successful switch', () async {
    final events = <String>[];
    final images = await prepareImages(events: events);
    final provider = _FakeMediaStorageProvider(
      events: events,
      deleteErrors: {
        'user_avatars/user-1/v7/thumb.jpg': StateError('delete failed'),
        'user_avatars/user-1/v7/full.jpg': StateError('delete failed'),
      },
    );
    final metadata = _FakeMetadataGateway(
      events: events,
      previousAvatar: _avatar(uid: 'user-1', version: 7),
    );
    final service = createService(
      provider: provider,
      metadata: metadata,
      version: 8,
    );

    final result = await service.replace(uid: 'user-1', images: images);

    expect(result.version, 8);
    expect(metadata.callCount, 1);
    expect(events.last, 'local-cleanup');
  });

  test(
    'local cleanup failure does not mask a successful replacement',
    () async {
      final events = <String>[];
      final images = await prepareImages(events: events, cleanupThrows: true);
      final service = createService(
        provider: _FakeMediaStorageProvider(events: events),
        metadata: _FakeMetadataGateway(events: events),
        version: 8,
      );

      final result = await service.replace(uid: 'user-1', images: images);

      expect(result.version, 8);
      expect(events.where((event) => event == 'local-cleanup'), hasLength(1));
    },
  );

  test('transaction conflict cleans the stale candidate version', () async {
    final events = <String>[];
    final images = await prepareImages(events: events);
    const conflict = AvatarVersionConflictException(
      candidateVersion: 8,
      activeVersion: 9,
    );
    final provider = _FakeMediaStorageProvider(events: events);
    final service = createService(
      provider: provider,
      metadata: _FakeMetadataGateway(events: events, error: conflict),
      version: 8,
    );

    await expectLater(
      service.replace(uid: 'user-1', images: images),
      throwsA(same(conflict)),
    );

    expect(provider.deletedPaths, [
      'user_avatars/user-1/v8/thumb.jpg',
      'user_avatars/user-1/v8/full.jpg',
    ]);
  });

  test('same-version conflict never deletes the active version', () async {
    final events = <String>[];
    final images = await prepareImages(events: events);
    const conflict = AvatarVersionConflictException(
      candidateVersion: 8,
      activeVersion: 8,
    );
    final provider = _FakeMediaStorageProvider(events: events);
    final service = createService(
      provider: provider,
      metadata: _FakeMetadataGateway(events: events, error: conflict),
      version: 8,
    );

    await expectLater(
      service.replace(uid: 'user-1', images: images),
      throwsA(same(conflict)),
    );

    expect(provider.deletedPaths, isEmpty);
  });

  test('transaction policy rejects non-increasing versions', () {
    expect(
      () => requireNewerAvatarVersion(candidateVersion: 20, activeVersion: 20),
      throwsA(
        isA<AvatarVersionConflictException>()
            .having((error) => error.candidateVersion, 'candidateVersion', 20)
            .having((error) => error.activeVersion, 'activeVersion', 20),
      ),
    );
    expect(
      () => requireNewerAvatarVersion(candidateVersion: 19, activeVersion: 20),
      throwsA(isA<AvatarVersionConflictException>()),
    );
    expect(
      () => requireNewerAvatarVersion(candidateVersion: 21, activeVersion: 20),
      returnsNormally,
    );
  });

  test(
    'rejects a non-positive generated version before remote calls',
    () async {
      final events = <String>[];
      final images = await prepareImages(events: events);
      final provider = _FakeMediaStorageProvider(events: events);
      final metadata = _FakeMetadataGateway(events: events);
      final service = createService(
        provider: provider,
        metadata: metadata,
        version: 0,
      );

      await expectLater(
        service.replace(uid: 'user-1', images: images),
        throwsA(isA<ArgumentError>()),
      );

      expect(provider.uploads, isEmpty);
      expect(metadata.callCount, 0);
      expect(events, ['local-cleanup']);
    },
  );

  test('public orchestration API contains no Firebase types', () {
    const publicBoundaryPaths = [
      'lib/services/avatar/atomic_avatar_replacement_service.dart',
      'lib/services/avatar/user_avatar_metadata_gateway.dart',
      'lib/services/avatar/avatar_storage_gateway.dart',
      'lib/services/avatar/avatar_storage_upload_service.dart',
    ];

    for (final path in publicBoundaryPaths) {
      final source = File(path).readAsStringSync();

      for (final forbiddenImport in [
        'package:firebase_',
        'package:cloud_firestore',
      ]) {
        expect(source, isNot(contains(forbiddenImport)), reason: path);
      }

      for (final forbiddenType in [
        'FirebaseStorage',
        'FirebaseFirestore',
        'DocumentReference',
        'DocumentSnapshot',
        'Transaction',
        'FieldValue',
      ]) {
        expect(
          source,
          isNot(matches(RegExp('\\b$forbiddenType\\b'))),
          reason: path,
        );
      }
    }
  });
}

final class _FakeCompressor implements AvatarImageCompressorGateway {
  int callCount = 0;

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    final size = callCount++ == 0 ? 1200 : 240000;
    final output = await File(request.targetPath).open(mode: FileMode.write);
    await output.truncate(size);
    await output.close();
    return AvatarCompressedImage(path: request.targetPath);
  }
}

final class _FakeMetadataGateway implements UserAvatarMetadataGateway {
  _FakeMetadataGateway({required this.events, this.previousAvatar, this.error});

  final List<String> events;
  final UserAvatar? previousAvatar;
  final Object? error;
  int callCount = 0;
  UserAvatar? lastAvatar;

  @override
  Future<UserAvatar?> replace({
    required String uid,
    required UserAvatar avatar,
  }) async {
    callCount++;
    lastAvatar = avatar;
    events.add('metadata:${avatar.version}');

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return previousAvatar;
  }
}

final class _FakeMediaStorageProvider implements AvatarStorageGateway {
  _FakeMediaStorageProvider({
    required this.events,
    this.uploadErrors = const {},
    this.deleteErrors = const {},
  });

  final List<String> events;
  final Map<String, Object> uploadErrors;
  final Map<String, Object> deleteErrors;
  final List<String> uploads = [];
  final List<String> deletedPaths = [];

  @override
  String get providerName => 'fake';

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
    uploads.add(path);
    events.add('upload:$path');

    final error = uploadErrors[path];

    if (error != null) {
      throw error;
    }

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
      updatedAt: DateTime.utc(2026, 7, 26),
    );
  }

  @override
  Future<void> deleteFile(String path) async {
    deletedPaths.add(path);
    events.add('delete:$path');

    final error = deleteErrors[path];

    if (error != null) {
      throw error;
    }
  }
}

UserAvatar _avatar({required String uid, required int version}) {
  return UserAvatar(
    thumbnail: MediaAsset(
      id: 'user-avatar-$uid-v$version-thumb',
      provider: 'fake',
      path: 'user_avatars/$uid/v$version/thumb.jpg',
      type: 'userAvatarThumbnail',
      ownerType: 'user',
      ownerId: uid,
      mimeType: 'image/jpeg',
      sizeBytes: 1200,
      version: version,
      updatedAt: DateTime.utc(2026, 7, 25),
    ),
    full: MediaAsset(
      id: 'user-avatar-$uid-v$version-full',
      provider: 'fake',
      path: 'user_avatars/$uid/v$version/full.jpg',
      type: 'userAvatarFull',
      ownerType: 'user',
      ownerId: uid,
      mimeType: 'image/jpeg',
      sizeBytes: 240000,
      version: version,
      updatedAt: DateTime.utc(2026, 7, 25),
    ),
  );
}
