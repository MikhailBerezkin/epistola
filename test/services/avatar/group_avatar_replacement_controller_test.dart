import 'dart:async';
import 'dart:io';

import 'package:epistola/domain/models/group_avatar.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_processor.dart';
import 'package:epistola/services/avatar/avatar_replacement_controller.dart';
import 'package:epistola/services/avatar/group_avatar_replacement_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;
  late File sourceFile;

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'epistola_group_avatar_controller_test_',
    );

    sourceFile = File(
      '${testDirectory.path}${Platform.pathSeparator}selected.jpg',
    );

    await sourceFile.writeAsBytes(List<int>.filled(32, 1));
  });

  tearDown(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('routes gallery and camera through requested preparation', () async {
    final sources = <AvatarReplacementSource>[];

    final controller = GroupAvatarReplacementController.withInvokers(
      prepare: (source) async {
        sources.add(source);
        return null;
      },
      replace: _unexpectedReplacement,
    );

    final gallery = await controller.replace(
      chatId: 'group-1',
      source: AvatarReplacementSource.gallery,
    );

    final camera = await controller.replace(
      chatId: 'group-1',
      source: AvatarReplacementSource.camera,
    );

    expect(sources, [
      AvatarReplacementSource.gallery,
      AvatarReplacementSource.camera,
    ]);

    expect(gallery.status, GroupAvatarReplacementStatus.cancelled);

    expect(camera.status, GroupAvatarReplacementStatus.cancelled);

    controller.dispose();
  });

  test('picker or crop cancellation does not start replacement', () async {
    var replacementCalls = 0;

    final controller = GroupAvatarReplacementController.withInvokers(
      prepare: (_) async => null,
      replace: ({required chatId, required images}) async {
        replacementCalls++;

        return _avatar(chatId: chatId, version: 2);
      },
    );

    final result = await controller.replace(
      chatId: 'group-1',
      source: AvatarReplacementSource.gallery,
    );

    expect(result.status, GroupAvatarReplacementStatus.cancelled);

    expect(result.error, isNull);
    expect(replacementCalls, 0);

    controller.dispose();
  });

  test('returns successful atomic replacement result', () async {
    final prepared = await _prepareImages(sourceFile);

    final expected = _avatar(chatId: 'group-1', version: 2);

    final controller = GroupAvatarReplacementController.withInvokers(
      prepare: (_) async => prepared.images,
      replace: ({required chatId, required images}) async {
        expect(chatId, 'group-1');
        expect(images, same(prepared.images));

        return expected;
      },
    );

    final result = await controller.replace(
      chatId: 'group-1',
      source: AvatarReplacementSource.gallery,
    );

    expect(result.status, GroupAvatarReplacementStatus.success);

    expect(result.avatar, same(expected));
    expect(result.error, isNull);
    expect(controller.latestAvatar, same(expected));
    expect(prepared.cleanupCalls, 1);

    controller.dispose();
  });

  test('reports preparation failure separately', () async {
    final error = StateError('Picker failed');

    final controller = GroupAvatarReplacementController.withInvokers(
      prepare: (_) async => throw error,
      replace: _unexpectedReplacement,
    );

    final result = await controller.replace(
      chatId: 'group-1',
      source: AvatarReplacementSource.camera,
    );

    expect(result.status, GroupAvatarReplacementStatus.failure);

    expect(result.failureStage, GroupAvatarReplacementFailureStage.preparation);

    expect(result.error, same(error));
    expect(result.avatar, isNull);
    expect(controller.latestAvatar, isNull);

    controller.dispose();
  });

  test('reports replacement failure without exposing new avatar', () async {
    final prepared = await _prepareImages(sourceFile);
    final error = StateError('Firestore switch failed');

    final controller = GroupAvatarReplacementController.withInvokers(
      prepare: (_) async => prepared.images,
      replace: ({required chatId, required images}) async {
        throw error;
      },
    );

    final result = await controller.replace(
      chatId: 'group-1',
      source: AvatarReplacementSource.gallery,
    );

    expect(result.status, GroupAvatarReplacementStatus.failure);

    expect(result.failureStage, GroupAvatarReplacementFailureStage.replacement);

    expect(result.error, same(error));
    expect(result.avatar, isNull);
    expect(controller.latestAvatar, isNull);
    expect(prepared.cleanupCalls, 1);

    controller.dispose();
  });

  test('blocks a second launch while operation is active', () async {
    final preparation = Completer<PreparedAvatarImages?>();
    var preparationCalls = 0;

    final controller = GroupAvatarReplacementController.withInvokers(
      prepare: (_) {
        preparationCalls++;
        return preparation.future;
      },
      replace: _unexpectedReplacement,
    );

    final first = controller.replace(
      chatId: 'group-1',
      source: AvatarReplacementSource.gallery,
    );

    final second = await controller.replace(
      chatId: 'group-1',
      source: AvatarReplacementSource.camera,
    );

    expect(controller.isLoading, isTrue);

    expect(second.status, GroupAvatarReplacementStatus.alreadyRunning);

    expect(preparationCalls, 1);

    preparation.complete(null);

    expect((await first).status, GroupAvatarReplacementStatus.cancelled);

    expect(controller.isLoading, isFalse);

    controller.dispose();
  });
}

Future<GroupAvatar> _unexpectedReplacement({
  required String chatId,
  required PreparedAvatarImages images,
}) {
  throw StateError('Replacement must not run.');
}

Future<_PreparedFixture> _prepareImages(File sourceFile) async {
  var cleanupCalls = 0;

  final processor = AvatarImageProcessor(
    compressor: _FakeCompressor(),
    cleanupInvoker: ({required workingDirectory, required filePaths}) async {
      cleanupCalls++;

      if (await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }

      return true;
    },
  );

  final images = await processor.process(sourceFile.path);

  return _PreparedFixture(images, () => cleanupCalls);
}

final class _PreparedFixture {
  const _PreparedFixture(this.images, this._cleanupCallReader);

  final PreparedAvatarImages images;
  final int Function() _cleanupCallReader;

  int get cleanupCalls => _cleanupCallReader();
}

final class _FakeCompressor implements AvatarImageCompressorGateway {
  int _callCount = 0;

  @override
  Future<AvatarCompressedImage?> compress(
    AvatarImageCompressionRequest request,
  ) async {
    final size = _callCount++ == 0 ? 1200 : 240000;
    final target = File(request.targetPath);

    await target.writeAsBytes(List<int>.filled(size, 1));

    return AvatarCompressedImage(path: target.path);
  }
}

GroupAvatar _avatar({required String chatId, required int version}) {
  final updatedAt = DateTime.utc(2026, 7, 28, 18);

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
