import 'dart:io';

import 'package:epistola/domain/models/group_avatar.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/services/avatar/atomic_group_avatar_replacement_service.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_processor.dart';
import 'package:epistola/services/avatar/avatar_storage_gateway.dart';
import 'package:epistola/services/avatar/group_avatar_metadata_gateway.dart';
import 'package:epistola/services/avatar/group_avatar_storage_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'epistola_atomic_group_avatar_test_',
    );
  });

  tearDown(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  Future<PreparedAvatarImages> prepareImages({
    required List<String> events,
  }) async {
    final source = File('${testDirectory.path}/source.jpg');
    await source.writeAsBytes(List<int>.filled(32, 1));

    final processor = AvatarImageProcessor(
      compressor: _FakeCompressor(),
      cleanupInvoker: ({required workingDirectory, required filePaths}) async {
        events.add('local-cleanup');

        if (await workingDirectory.exists()) {
          await workingDirectory.delete(recursive: true);
        }

        return true;
      },
    );

    return processor.process(source.path);
  }

  AtomicGroupAvatarReplacementService createService({
    required _FakeStorageGateway provider,
    required GroupAvatarMetadataGateway metadata,
    required int version,
  }) {
    return AtomicGroupAvatarReplacementService(
      storage: GroupAvatarStorageUploadService(provider: provider),
      metadata: metadata,
      versionGenerator: () => version,
    );
  }

  test(
    'orders upload, metadata switch, old delete, and local cleanup',
    () async {
      final events = <String>[];
      final images = await prepareImages(events: events);
      final provider = _FakeStorageGateway(events: events);

      final metadata = _FakeMetadataGateway(
        events: events,
        previousAvatar: _avatar(chatId: 'group-1', version: 7),
      );

      final service = createService(
        provider: provider,
        metadata: metadata,
        version: 8,
      );

      final result = await service.replace(chatId: 'group-1', images: images);

      expect(result.version, 8);
      expect(events, [
        'upload:group_avatars/group-1/v8/thumb.jpg',
        'upload:group_avatars/group-1/v8/full.jpg',
        'metadata:8',
        'delete:group_avatars/group-1/v7/thumb.jpg',
        'delete:group_avatars/group-1/v7/full.jpg',
        'local-cleanup',
      ]);
      expect(metadata.lastAvatar, same(result));
    },
  );

  test('first avatar does not delete an old version', () async {
    final events = <String>[];
    final images = await prepareImages(events: events);
    final provider = _FakeStorageGateway(events: events);

    final service = createService(
      provider: provider,
      metadata: _FakeMetadataGateway(events: events),
      version: 1,
    );

    await service.replace(chatId: 'group-1', images: images);

    expect(provider.deletedPaths, isEmpty);
    expect(events.last, 'local-cleanup');
  });

  test('metadata failure deletes only the newly uploaded version', () async {
    final events = <String>[];
    final images = await prepareImages(events: events);
    final provider = _FakeStorageGateway(events: events);
    final metadataError = StateError('Firestore failed');

    final service = createService(
      provider: provider,
      metadata: _FakeMetadataGateway(events: events, error: metadataError),
      version: 8,
    );

    await expectLater(
      service.replace(chatId: 'group-1', images: images),
      throwsA(same(metadataError)),
    );

    expect(provider.deletedPaths, [
      'group_avatars/group-1/v8/thumb.jpg',
      'group_avatars/group-1/v8/full.jpg',
    ]);
    expect(events.last, 'local-cleanup');
  });

  test('version conflict cleans a stale candidate version', () async {
    final events = <String>[];
    final images = await prepareImages(events: events);
    final provider = _FakeStorageGateway(events: events);

    const conflict = GroupAvatarVersionConflictException(
      candidateVersion: 8,
      activeVersion: 9,
    );

    final service = createService(
      provider: provider,
      metadata: _FakeMetadataGateway(events: events, error: conflict),
      version: 8,
    );

    await expectLater(
      service.replace(chatId: 'group-1', images: images),
      throwsA(same(conflict)),
    );

    expect(provider.deletedPaths, [
      'group_avatars/group-1/v8/thumb.jpg',
      'group_avatars/group-1/v8/full.jpg',
    ]);
  });

  test('same-version conflict never deletes the active version', () async {
    final events = <String>[];
    final images = await prepareImages(events: events);
    final provider = _FakeStorageGateway(events: events);

    const conflict = GroupAvatarVersionConflictException(
      candidateVersion: 8,
      activeVersion: 8,
    );

    final service = createService(
      provider: provider,
      metadata: _FakeMetadataGateway(events: events, error: conflict),
      version: 8,
    );

    await expectLater(
      service.replace(chatId: 'group-1', images: images),
      throwsA(same(conflict)),
    );

    expect(provider.deletedPaths, isEmpty);
  });

  test('invalid generated version performs no remote calls', () async {
    final events = <String>[];
    final images = await prepareImages(events: events);
    final provider = _FakeStorageGateway(events: events);
    final metadata = _FakeMetadataGateway(events: events);

    final service = createService(
      provider: provider,
      metadata: metadata,
      version: 0,
    );

    await expectLater(
      service.replace(chatId: 'group-1', images: images),
      throwsArgumentError,
    );

    expect(provider.uploads, isEmpty);
    expect(metadata.callCount, 0);
    expect(events, ['local-cleanup']);
  });
}

final class _FakeCompressor implements AvatarImageCompressorGateway {
  int callCount = 0;

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    final sizeBytes = callCount++ == 0 ? 1200 : 240000;
    final target = File(request.targetPath);

    await target.writeAsBytes(List<int>.filled(sizeBytes, 1));

    return AvatarCompressedImage(path: target.path);
  }
}

final class _FakeMetadataGateway implements GroupAvatarMetadataGateway {
  _FakeMetadataGateway({required this.events, this.previousAvatar, this.error});

  final List<String> events;
  final GroupAvatar? previousAvatar;
  final Object? error;

  int callCount = 0;
  GroupAvatar? lastAvatar;

  @override
  Future<GroupAvatar?> replace({
    required String chatId,
    required GroupAvatar avatar,
  }) async {
    callCount++;
    lastAvatar = avatar;
    events.add('metadata:${avatar.version}');

    final failure = error;

    if (failure != null) {
      throw failure;
    }

    return previousAvatar;
  }
}

final class _FakeStorageGateway implements AvatarStorageGateway {
  _FakeStorageGateway({required this.events});

  final List<String> events;
  final uploads = <String>[];
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
    uploads.add(path);
    events.add('upload:$path');

    final now = DateTime.utc(2026, 7, 28, 17);

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
    events.add('delete:$path');
  }
}

GroupAvatar _avatar({required String chatId, required int version}) {
  final updatedAt = DateTime.utc(2026, 7, 28, 17);

  return GroupAvatar(
    thumbnail: MediaAsset(
      id: 'group-avatar-$chatId-v$version-thumb',
      provider: 'firebase',
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
      provider: 'firebase',
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
