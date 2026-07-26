import 'dart:io';

import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/domain/models/user_avatar.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_pipeline_config.dart';
import 'package:epistola/services/avatar/avatar_image_processor.dart';
import 'package:epistola/services/avatar/avatar_storage_upload_service.dart';
import 'package:epistola/services/media/media_storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;
  late File croppedSource;
  late File originalSource;
  final preparedResults = <PreparedAvatarImages>[];

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'epistola_avatar_storage_upload_test_',
    );
    originalSource = await _createFile(
      testDirectory,
      'original.jpg',
      sizeBytes: 17,
    );
    croppedSource = await _createFile(
      testDirectory,
      'cropped.jpg',
      sizeBytes: 23,
    );
  });

  tearDown(() async {
    for (final images in preparedResults) {
      await images.cleanup();
    }
    preparedResults.clear();

    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  Future<PreparedAvatarImages> prepareImages({
    int thumbnailBytes = 1200,
    int fullBytes = 240000,
    AvatarImageCleanupInvoker? cleanupInvoker,
  }) async {
    final processor = AvatarImageProcessor(
      compressor: _FakeCompressor(
        thumbnailBytes: thumbnailBytes,
        fullBytes: fullBytes,
      ),
      cleanupInvoker: cleanupInvoker ?? _deletePreparedFiles,
    );
    final images = await processor.process(croppedSource.path);
    preparedResults.add(images);
    return images;
  }

  test('uploads both JPEG variants to the exact versioned paths', () async {
    final images = await prepareImages();
    final provider = _FakeMediaStorageProvider();
    final service = AvatarStorageUploadService(provider: provider);

    final avatar = await service.upload(
      uid: 'user-42',
      version: 7,
      images: images,
    );

    expect(provider.uploads, hasLength(2));
    expect(provider.uploads.map((upload) => upload.path), [
      'user_avatars/user-42/v7/thumb.jpg',
      'user_avatars/user-42/v7/full.jpg',
    ]);
    expect(provider.uploads.map((upload) => upload.mimeType).toSet(), {
      'image/jpeg',
    });
    expect(avatar.isComplete, isTrue);
  });

  test('returns URLs, byte sizes, dimensions, and version', () async {
    final images = await prepareImages(thumbnailBytes: 3210, fullBytes: 234567);
    final provider = _FakeMediaStorageProvider();
    final service = AvatarStorageUploadService(provider: provider);

    final avatar = await service.upload(
      uid: 'user-1',
      version: 9,
      images: images,
    );

    expect(
      avatar.thumbnailUrl,
      'https://storage.example/user_avatars/user-1/v9/thumb.jpg',
    );
    expect(
      avatar.fullUrl,
      'https://storage.example/user_avatars/user-1/v9/full.jpg',
    );
    expect(avatar.thumbnailStoragePath, 'user_avatars/user-1/v9/thumb.jpg');
    expect(avatar.fullStoragePath, 'user_avatars/user-1/v9/full.jpg');
    expect(avatar.thumbnail.sizeBytes, 3210);
    expect(avatar.full.sizeBytes, 234567);
    expect(avatar.thumbnail.width, 128);
    expect(avatar.thumbnail.height, 128);
    expect(avatar.full.width, 512);
    expect(avatar.full.height, 512);
    expect(avatar.thumbnail.mimeType, 'image/jpeg');
    expect(avatar.full.mimeType, 'image/jpeg');
    expect(avatar.version, 9);
    expect(avatar.thumbnail.version, 9);
  });

  test('rejects an empty uid before a network call', () async {
    final images = await prepareImages();
    final provider = _FakeMediaStorageProvider();
    final service = AvatarStorageUploadService(provider: provider);

    await expectLater(
      service.upload(uid: '   ', version: 1, images: images),
      throwsA(
        isA<ArgumentError>().having((error) => error.name, 'name', 'uid'),
      ),
    );

    expect(provider.uploads, isEmpty);
    expect(provider.deletedPaths, isEmpty);
  });

  for (final invalidVersion in [0, -1]) {
    test('rejects version $invalidVersion before a network call', () async {
      final images = await prepareImages();
      final provider = _FakeMediaStorageProvider();
      final service = AvatarStorageUploadService(provider: provider);

      await expectLater(
        service.upload(uid: 'user-1', version: invalidVersion, images: images),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'version'),
        ),
      );

      expect(provider.uploads, isEmpty);
      expect(provider.deletedPaths, isEmpty);
    });
  }

  test('rejects a full image over 512 KB before a network call', () async {
    final images = await prepareImages();
    await File(images.fullPath).writeAsBytes(
      List.filled(AvatarImagePipelineConfig.hardFullSizeBytes + 1, 0),
    );
    final provider = _FakeMediaStorageProvider();
    final service = AvatarStorageUploadService(provider: provider);

    await expectLater(
      service.upload(uid: 'user-1', version: 2, images: images),
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

    expect(provider.uploads, isEmpty);
    expect(provider.deletedPaths, isEmpty);
  });

  test('cleans only the new version when thumbnail upload fails', () async {
    final images = await prepareImages();
    final uploadError = StateError('thumbnail upload failed');
    final thumbnailPath = 'user_avatars/user-1/v4/thumb.jpg';
    final provider = _FakeMediaStorageProvider(
      uploadErrors: {thumbnailPath: uploadError},
    );
    final service = AvatarStorageUploadService(provider: provider);

    await expectLater(
      service.upload(uid: 'user-1', version: 4, images: images),
      throwsA(same(uploadError)),
    );

    expect(provider.uploads, hasLength(1));
    expect(provider.uploads.single.path, thumbnailPath);
    expect(provider.deletedPaths, [
      thumbnailPath,
      'user_avatars/user-1/v4/full.jpg',
    ]);
    expect(
      provider.deletedPaths.every(
        (path) => path.startsWith('user_avatars/user-1/v4/'),
      ),
      isTrue,
    );
  });

  test('cleans both new-version paths after full upload fails', () async {
    final images = await prepareImages();
    final uploadError = StateError('full upload failed');
    final fullPath = 'user_avatars/user-1/v5/full.jpg';
    final provider = _FakeMediaStorageProvider(
      uploadErrors: {fullPath: uploadError},
    );
    final service = AvatarStorageUploadService(provider: provider);

    await expectLater(
      service.upload(uid: 'user-1', version: 5, images: images),
      throwsA(same(uploadError)),
    );

    expect(provider.uploads.map((upload) => upload.path), [
      'user_avatars/user-1/v5/thumb.jpg',
      fullPath,
    ]);
    expect(provider.deletedPaths, [
      'user_avatars/user-1/v5/thumb.jpg',
      fullPath,
    ]);
  });

  test('preserves the upload error when every cleanup delete fails', () async {
    final images = await prepareImages();
    final uploadError = StateError('full upload failed');
    final thumbnailPath = 'user_avatars/user-1/v6/thumb.jpg';
    final fullPath = 'user_avatars/user-1/v6/full.jpg';
    final provider = _FakeMediaStorageProvider(
      uploadErrors: {fullPath: uploadError},
      deleteErrors: {
        thumbnailPath: StateError('thumbnail cleanup failed'),
        fullPath: StateError('full cleanup failed'),
      },
    );
    final service = AvatarStorageUploadService(provider: provider);

    await expectLater(
      service.upload(uid: 'user-1', version: 6, images: images),
      throwsA(same(uploadError)),
    );

    expect(provider.deletedPaths, [thumbnailPath, fullPath]);
  });

  test('never deletes an older active version', () async {
    final images = await prepareImages();
    final uploadError = StateError('full upload failed');
    final provider = _FakeMediaStorageProvider(
      uploadErrors: {'user_avatars/user-1/v8/full.jpg': uploadError},
    );
    final service = AvatarStorageUploadService(provider: provider);

    await expectLater(
      service.upload(uid: 'user-1', version: 8, images: images),
      throwsA(same(uploadError)),
    );

    expect(
      provider.deletedPaths,
      isNot(contains('user_avatars/user-1/v7/thumb.jpg')),
    );
    expect(
      provider.deletedPaths,
      isNot(contains('user_avatars/user-1/v7/full.jpg')),
    );
    expect(
      provider.deletedPaths.every((path) => path.contains('/v8/')),
      isTrue,
    );
  });

  test('uploads neither the original nor cropped source', () async {
    final images = await prepareImages();
    final provider = _FakeMediaStorageProvider();
    final service = AvatarStorageUploadService(provider: provider);

    await service.upload(uid: 'user-1', version: 3, images: images);

    expect(provider.uploads.map((upload) => upload.localPath).toSet(), {
      images.thumbnailPath,
      images.fullPath,
    });
    expect(
      provider.uploads.map((upload) => upload.localPath),
      isNot(contains(originalSource.path)),
    );
    expect(
      provider.uploads.map((upload) => upload.localPath),
      isNot(contains(croppedSource.path)),
    );
  });

  test('does not take ownership of PreparedAvatarImages cleanup', () async {
    var cleanupCallCount = 0;
    final images = await prepareImages(
      cleanupInvoker: ({required workingDirectory, required filePaths}) async {
        cleanupCallCount++;
        return _deletePreparedFiles(
          workingDirectory: workingDirectory,
          filePaths: filePaths,
        );
      },
    );
    final service = AvatarStorageUploadService(
      provider: _FakeMediaStorageProvider(),
    );

    await service.upload(uid: 'user-1', version: 10, images: images);

    expect(cleanupCallCount, 0);
    expect(await File(images.thumbnailPath).exists(), isTrue);
    expect(await File(images.fullPath).exists(), isTrue);
  });

  test(
    'deletes only the exact versioned paths owned by the current uid',
    () async {
      final provider = _FakeMediaStorageProvider();
      final service = AvatarStorageUploadService(provider: provider);

      await service.deleteAvatarVersion(
        uid: 'user-1',
        avatar: _avatar(
          uid: 'user-1',
          version: 11,
          provider: provider.providerName,
        ),
        activeVersion: 12,
      );

      expect(provider.deletedPaths, [
        'user_avatars/user-1/v11/thumb.jpg',
        'user_avatars/user-1/v11/full.jpg',
      ]);
    },
  );

  test('refuses versioned paths belonging to another uid', () async {
    final provider = _FakeMediaStorageProvider();
    final service = AvatarStorageUploadService(provider: provider);

    await service.deleteAvatarVersion(
      uid: 'user-1',
      avatar: _avatar(
        uid: 'other-user',
        version: 11,
        provider: provider.providerName,
      ),
      activeVersion: 12,
    );

    expect(provider.deletedPaths, isEmpty);
  });

  test('refuses external and legacy avatar paths', () async {
    final provider = _FakeMediaStorageProvider();
    final service = AvatarStorageUploadService(provider: provider);
    final externalAvatar = UserAvatar(
      thumbnail: MediaAsset(
        id: 'legacy-thumb',
        provider: provider.providerName,
        path: 'https://example.com/legacy-thumb.jpg',
        type: 'userAvatarThumbnail',
        ownerType: 'user',
        ownerId: 'user-1',
        version: 4,
        downloadUrl: 'https://example.com/legacy-thumb.jpg',
      ),
      full: MediaAsset(
        id: 'legacy-full',
        provider: provider.providerName,
        path: 'user_avatars/user-1/avatar.jpg',
        type: 'userAvatarFull',
        ownerType: 'user',
        ownerId: 'user-1',
        version: 4,
        downloadUrl: 'https://example.com/legacy-full.jpg',
      ),
    );

    await service.deleteAvatarVersion(
      uid: 'user-1',
      avatar: externalAvatar,
      activeVersion: 5,
    );

    expect(provider.deletedPaths, isEmpty);
  });

  test('never deletes the protected active version', () async {
    final provider = _FakeMediaStorageProvider();
    final service = AvatarStorageUploadService(provider: provider);

    await service.deleteAvatarVersion(
      uid: 'user-1',
      avatar: _avatar(
        uid: 'user-1',
        version: 11,
        provider: provider.providerName,
      ),
      activeVersion: 11,
    );

    expect(provider.deletedPaths, isEmpty);
  });

  test('public upload boundary has no Firebase or Firestore types', () {
    const publicBoundaryPaths = [
      'lib/services/avatar/avatar_storage_upload_service.dart',
      'lib/services/media/media_storage_provider.dart',
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
        'Reference',
        'UploadTask',
        'TaskSnapshot',
        'SettableMetadata',
        'DocumentReference',
        'DocumentSnapshot',
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

UserAvatar _avatar({
  required String uid,
  required int version,
  required String provider,
}) {
  return UserAvatar(
    thumbnail: MediaAsset(
      id: 'user-avatar-$uid-v$version-thumb',
      provider: provider,
      path: 'user_avatars/$uid/v$version/thumb.jpg',
      type: 'userAvatarThumbnail',
      ownerType: 'user',
      ownerId: uid,
      mimeType: 'image/jpeg',
      version: version,
      downloadUrl: 'https://storage.example/thumb.jpg',
    ),
    full: MediaAsset(
      id: 'user-avatar-$uid-v$version-full',
      provider: provider,
      path: 'user_avatars/$uid/v$version/full.jpg',
      type: 'userAvatarFull',
      ownerType: 'user',
      ownerId: uid,
      mimeType: 'image/jpeg',
      version: version,
      downloadUrl: 'https://storage.example/full.jpg',
    ),
  );
}

Future<File> _createFile(
  Directory directory,
  String name, {
  required int sizeBytes,
}) async {
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  final output = await file.open(mode: FileMode.write);
  await output.truncate(sizeBytes);
  await output.close();
  return file;
}

Future<bool> _deletePreparedFiles({
  required Directory workingDirectory,
  required Iterable<String> filePaths,
}) async {
  if (await workingDirectory.exists()) {
    await workingDirectory.delete(recursive: true);
  }

  return !await workingDirectory.exists();
}

final class _FakeCompressor implements AvatarImageCompressorGateway {
  _FakeCompressor({required this.thumbnailBytes, required this.fullBytes});

  final int thumbnailBytes;
  final int fullBytes;
  int callCount = 0;

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    final sizeBytes = callCount++ == 0 ? thumbnailBytes : fullBytes;
    final output = await File(request.targetPath).open(mode: FileMode.write);
    await output.truncate(sizeBytes);
    await output.close();
    return AvatarCompressedImage(path: request.targetPath);
  }
}

final class _FakeMediaStorageProvider implements MediaStorageProvider {
  _FakeMediaStorageProvider({
    this.uploadErrors = const {},
    this.deleteErrors = const {},
  });

  final Map<String, Object> uploadErrors;
  final Map<String, Object> deleteErrors;
  final List<_UploadCall> uploads = [];
  final List<String> deletedPaths = [];

  @override
  String get providerName => 'fake';

  @override
  Future<MediaAsset> uploadFile({
    required File file,
    required String path,
    required String type,
    String? ownerType,
    String? ownerId,
    String? mimeType,
    int version = 1,
  }) async {
    uploads.add(
      _UploadCall(localPath: file.path, path: path, mimeType: mimeType),
    );

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
      downloadUrl: 'https://storage.example/$path',
    );
  }

  @override
  Future<void> deleteFile(String path) async {
    deletedPaths.add(path);

    final error = deleteErrors[path];

    if (error != null) {
      throw error;
    }
  }

  @override
  Future<String> getDownloadUrl(String path) async {
    return 'https://storage.example/$path';
  }
}

final class _UploadCall {
  const _UploadCall({
    required this.localPath,
    required this.path,
    required this.mimeType,
  });

  final String localPath;
  final String path;
  final String? mimeType;
}
