import 'dart:io';

import 'package:epistola/domain/models/group_avatar.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_pipeline_config.dart';
import 'package:epistola/services/avatar/avatar_image_processor.dart';
import 'package:epistola/services/avatar/avatar_storage_gateway.dart';
import 'package:epistola/services/avatar/group_avatar_storage_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;
  late File source;
  final preparedImages = <PreparedAvatarImages>[];

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'epistola_group_avatar_upload_test_',
    );

    source = File('${testDirectory.path}/source.jpg');
    await source.writeAsBytes(List<int>.filled(32, 1));
  });

  tearDown(() async {
    for (final images in preparedImages) {
      await images.cleanup();
    }

    preparedImages.clear();

    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  Future<PreparedAvatarImages> prepareImages({
    AvatarImageCleanupInvoker? cleanupInvoker,
  }) async {
    final processor = cleanupInvoker == null
        ? AvatarImageProcessor(compressor: _FakeCompressor())
        : AvatarImageProcessor(
            compressor: _FakeCompressor(),
            cleanupInvoker: cleanupInvoker,
          );

    final images = await processor.process(source.path);
    preparedImages.add(images);

    return images;
  }

  test('uploads both variants to exact group versioned paths', () async {
    final images = await prepareImages();
    final provider = _FakeAvatarStorageGateway();
    final service = GroupAvatarStorageUploadService(provider: provider);

    final avatar = await service.upload(
      chatId: 'group-42',
      version: 7,
      images: images,
    );

    expect(provider.uploads.map((upload) => upload.path), [
      'group_avatars/group-42/v7/thumb.jpg',
      'group_avatars/group-42/v7/full.jpg',
    ]);

    expect(provider.uploads.map((upload) => upload.ownerType).toSet(), {
      'group',
    });

    expect(provider.uploads.map((upload) => upload.ownerId).toSet(), {
      'group-42',
    });

    expect(avatar.thumbnailStoragePath, 'group_avatars/group-42/v7/thumb.jpg');
    expect(avatar.fullStoragePath, 'group_avatars/group-42/v7/full.jpg');
    expect(avatar.thumbnail.width, 128);
    expect(avatar.thumbnail.height, 128);
    expect(avatar.full.width, 512);
    expect(avatar.full.height, 512);
    expect(avatar.isComplete, isTrue);
    expect(avatar.hasPersistableMetadata, isTrue);
  });

  test('rejects an empty chat id before upload', () async {
    final images = await prepareImages();
    final provider = _FakeAvatarStorageGateway();
    final service = GroupAvatarStorageUploadService(provider: provider);

    await expectLater(
      service.upload(chatId: '   ', version: 1, images: images),
      throwsA(
        isA<ArgumentError>().having((error) => error.name, 'name', 'chatId'),
      ),
    );

    expect(provider.uploads, isEmpty);
    expect(provider.deletedPaths, isEmpty);
  });

  test('cleans both new paths when full upload fails', () async {
    final images = await prepareImages();
    final uploadError = StateError('full upload failed');

    final provider = _FakeAvatarStorageGateway(
      uploadErrors: {'group_avatars/group-1/v5/full.jpg': uploadError},
    );

    final service = GroupAvatarStorageUploadService(provider: provider);

    await expectLater(
      service.upload(chatId: 'group-1', version: 5, images: images),
      throwsA(same(uploadError)),
    );

    expect(provider.uploads.map((upload) => upload.path), [
      'group_avatars/group-1/v5/thumb.jpg',
      'group_avatars/group-1/v5/full.jpg',
    ]);

    expect(provider.deletedPaths, [
      'group_avatars/group-1/v5/thumb.jpg',
      'group_avatars/group-1/v5/full.jpg',
    ]);
  });

  test('does not take ownership of prepared image cleanup', () async {
    var cleanupCallCount = 0;

    final images = await prepareImages(
      cleanupInvoker: ({required workingDirectory, required filePaths}) async {
        cleanupCallCount++;

        if (await workingDirectory.exists()) {
          await workingDirectory.delete(recursive: true);
        }

        return true;
      },
    );

    final service = GroupAvatarStorageUploadService(
      provider: _FakeAvatarStorageGateway(),
    );

    await service.upload(chatId: 'group-1', version: 8, images: images);

    expect(cleanupCallCount, 0);
    expect(await File(images.thumbnailPath).exists(), isTrue);
    expect(await File(images.fullPath).exists(), isTrue);
  });

  test('deletes only an inactive version owned by the group', () async {
    final provider = _FakeAvatarStorageGateway();
    final service = GroupAvatarStorageUploadService(provider: provider);

    await service.deleteAvatarVersion(
      chatId: 'group-1',
      avatar: _avatar(
        chatId: 'group-1',
        version: 11,
        provider: provider.providerName,
      ),
      activeVersion: 12,
    );

    expect(provider.deletedPaths, [
      'group_avatars/group-1/v11/thumb.jpg',
      'group_avatars/group-1/v11/full.jpg',
    ]);
  });

  test('refuses to delete the active version', () async {
    final provider = _FakeAvatarStorageGateway();
    final service = GroupAvatarStorageUploadService(provider: provider);

    await service.deleteAvatarVersion(
      chatId: 'group-1',
      avatar: _avatar(
        chatId: 'group-1',
        version: 12,
        provider: provider.providerName,
      ),
      activeVersion: 12,
    );

    expect(provider.deletedPaths, isEmpty);
  });
}

final class _FakeCompressor implements AvatarImageCompressorGateway {
  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    final isThumbnail =
        request.width == AvatarImagePipelineConfig.thumbnail.width;

    final sizeBytes = isThumbnail ? 1200 : 240000;
    final target = File(request.targetPath);

    await target.writeAsBytes(List<int>.filled(sizeBytes, isThumbnail ? 1 : 2));

    return AvatarCompressedImage(path: target.path);
  }
}

final class _FakeAvatarStorageGateway implements AvatarStorageGateway {
  _FakeAvatarStorageGateway({this.uploadErrors = const {}});

  final Map<String, Object> uploadErrors;

  final uploads = <_UploadRecord>[];
  final deletedPaths = <String>[];

  @override
  String get providerName => 'firebase';

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
    uploads.add(
      _UploadRecord(
        path: path,
        type: type,
        ownerType: ownerType,
        ownerId: ownerId,
      ),
    );

    final error = uploadErrors[path];

    if (error != null) {
      throw error;
    }

    final now = DateTime.utc(2026, 7, 28, 15);

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
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> deleteFile(String path) async {
    deletedPaths.add(path);
  }
}

final class _UploadRecord {
  const _UploadRecord({
    required this.path,
    required this.type,
    required this.ownerType,
    required this.ownerId,
  });

  final String path;
  final String type;
  final String ownerType;
  final String ownerId;
}

GroupAvatar _avatar({
  required String chatId,
  required int version,
  required String provider,
}) {
  final updatedAt = DateTime.utc(2026, 7, 28, 15);

  return GroupAvatar(
    thumbnail: MediaAsset(
      id: 'group-avatar-$chatId-v$version-thumb',
      provider: provider,
      path: 'group_avatars/$chatId/v$version/thumb.jpg',
      type: 'groupAvatarThumbnail',
      ownerType: 'group',
      ownerId: chatId,
      mimeType: 'image/jpeg',
      sizeBytes: 1200,
      width: 128,
      height: 128,
      version: version,
      updatedAt: updatedAt,
    ),
    full: MediaAsset(
      id: 'group-avatar-$chatId-v$version-full',
      provider: provider,
      path: 'group_avatars/$chatId/v$version/full.jpg',
      type: 'groupAvatarFull',
      ownerType: 'group',
      ownerId: chatId,
      mimeType: 'image/jpeg',
      sizeBytes: 240000,
      width: 512,
      height: 512,
      version: version,
      updatedAt: updatedAt,
    ),
  );
}
