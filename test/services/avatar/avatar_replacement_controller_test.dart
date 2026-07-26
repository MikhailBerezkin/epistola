import 'dart:async';
import 'dart:io';

import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/domain/models/user_avatar.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_processor.dart';
import 'package:epistola/services/avatar/avatar_replacement_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;
  late File sourceFile;

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'epistola_avatar_replacement_controller_test_',
    );
    sourceFile = File(
      '${testDirectory.path}${Platform.pathSeparator}selected.jpg',
    );
    await sourceFile.writeAsBytes(List.filled(32, 1));
  });

  tearDown(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test(
    'routes gallery and camera through the requested preparation path',
    () async {
      final sources = <AvatarReplacementSource>[];
      final controller = AvatarReplacementController.withInvokers(
        prepare: (source) async {
          sources.add(source);
          return null;
        },
        replace: _unexpectedReplacement,
      );

      final gallery = await controller.replace(
        uid: 'user-1',
        source: AvatarReplacementSource.gallery,
      );
      final camera = await controller.replace(
        uid: 'user-1',
        source: AvatarReplacementSource.camera,
      );

      expect(sources, [
        AvatarReplacementSource.gallery,
        AvatarReplacementSource.camera,
      ]);
      expect(gallery.status, AvatarReplacementStatus.cancelled);
      expect(camera.status, AvatarReplacementStatus.cancelled);
    },
  );

  test('picker cancellation is a normal result without replacement', () async {
    var replacementCalls = 0;
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async => null,
      replace: ({required uid, required images}) async {
        replacementCalls++;
        return _avatar(uid: uid, version: 2);
      },
    );

    final result = await controller.replace(
      uid: 'user-1',
      source: AvatarReplacementSource.gallery,
    );

    expect(result.status, AvatarReplacementStatus.cancelled);
    expect(result.error, isNull);
    expect(replacementCalls, 0);
  });

  test('crop cancellation is a normal result without replacement', () async {
    var replacementCalls = 0;
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async {
        // AvatarImagePreparationService represents both picker and crop
        // cancellation with null.
        return null;
      },
      replace: ({required uid, required images}) async {
        replacementCalls++;
        return _avatar(uid: uid, version: 2);
      },
    );

    final result = await controller.replace(
      uid: 'user-1',
      source: AvatarReplacementSource.camera,
    );

    expect(result.status, AvatarReplacementStatus.cancelled);
    expect(result.error, isNull);
    expect(replacementCalls, 0);
  });

  test('returns the successful atomic replacement result', () async {
    final prepared = await _prepareImages(sourceFile);
    final expected = _avatar(uid: 'user-1', version: 2);
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async => prepared.images,
      replace: ({required uid, required images}) async {
        expect(uid, 'user-1');
        expect(images, same(prepared.images));
        return expected;
      },
    );

    final result = await controller.replace(
      uid: 'user-1',
      source: AvatarReplacementSource.gallery,
    );

    expect(result.status, AvatarReplacementStatus.success);
    expect(result.avatar, same(expected));
    expect(result.error, isNull);
  });

  test('reports replacement failure without exposing a new avatar', () async {
    final prepared = await _prepareImages(sourceFile);
    final error = StateError('Firestore switch failed');
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async => prepared.images,
      replace: ({required uid, required images}) async => throw error,
    );

    final result = await controller.replace(
      uid: 'user-1',
      source: AvatarReplacementSource.gallery,
    );

    expect(result.status, AvatarReplacementStatus.failure);
    expect(result.failureStage, AvatarReplacementFailureStage.replacement);
    expect(result.error, same(error));
    expect(result.avatar, isNull);
  });

  test('cleans prepared images after success and after failure', () async {
    final successPrepared = await _prepareImages(sourceFile);
    final failurePrepared = await _prepareImages(sourceFile);
    var call = 0;
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async {
        return call++ == 0 ? successPrepared.images : failurePrepared.images;
      },
      replace: ({required uid, required images}) async {
        if (identical(images, failurePrepared.images)) {
          throw StateError('upload failed');
        }
        return _avatar(uid: uid, version: 2);
      },
    );

    await controller.replace(
      uid: 'user-1',
      source: AvatarReplacementSource.gallery,
    );
    await controller.replace(
      uid: 'user-1',
      source: AvatarReplacementSource.camera,
    );

    expect(successPrepared.cleanupCalls, 1);
    expect(failurePrepared.cleanupCalls, 1);
    expect(await sourceFile.exists(), isTrue);
  });

  test('blocks a second launch while an operation is active', () async {
    final preparation = Completer<PreparedAvatarImages?>();
    var preparationCalls = 0;
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) {
        preparationCalls++;
        return preparation.future;
      },
      replace: _unexpectedReplacement,
    );

    final first = controller.replace(
      uid: 'user-1',
      source: AvatarReplacementSource.gallery,
    );
    final second = await controller.replace(
      uid: 'user-1',
      source: AvatarReplacementSource.camera,
    );

    expect(controller.isLoading, isTrue);
    expect(second.status, AvatarReplacementStatus.alreadyRunning);
    expect(preparationCalls, 1);

    preparation.complete(null);
    expect((await first).status, AvatarReplacementStatus.cancelled);
    expect(controller.isLoading, isFalse);
  });
}

Future<UserAvatar> _unexpectedReplacement({
  required String uid,
  required PreparedAvatarImages images,
}) {
  throw StateError('replacement must not run');
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
    final output = await File(request.targetPath).open(mode: FileMode.write);
    await output.truncate(size);
    await output.close();
    return AvatarCompressedImage(path: request.targetPath);
  }
}

UserAvatar _avatar({required String uid, required int version}) {
  return UserAvatar(
    thumbnail: MediaAsset(
      id: 'thumb-$version',
      provider: 'fake',
      path: 'user_avatars/$uid/v$version/thumb.jpg',
      type: 'userAvatarThumbnail',
      ownerType: 'user',
      ownerId: uid,
      mimeType: 'image/jpeg',
      sizeBytes: 1200,
      version: version,
      updatedAt: DateTime.utc(2026, 7, 26),
    ),
    full: MediaAsset(
      id: 'full-$version',
      provider: 'fake',
      path: 'user_avatars/$uid/v$version/full.jpg',
      type: 'userAvatarFull',
      ownerType: 'user',
      ownerId: uid,
      mimeType: 'image/jpeg',
      sizeBytes: 240000,
      version: version,
      updatedAt: DateTime.utc(2026, 7, 26),
    ),
  );
}
