import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/domain/models/user_avatar.dart';
import 'package:epistola/models/app_user.dart';
import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_loader.dart';
import 'package:epistola/services/avatar/avatar_image_processor.dart';
import 'package:epistola/services/avatar/avatar_replacement_controller.dart';
import 'package:epistola/widgets/avatar/user_avatar_view.dart';
import 'package:epistola/widgets/profile_avatar_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;
  late File sourceFile;

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'epistola_profile_avatar_editor_test_',
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

  const user = AppUser(
    uid: 'user-1',
    email: 'user@example.com',
    name: 'Иван Петров',
    phone: '',
    about: '',
  );

  testWidgets('avatar opens the source bottom sheet and cancel is normal', (
    tester,
  ) async {
    var preparationCalls = 0;
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async {
        preparationCalls++;
        return null;
      },
      replace: _unexpectedReplacement,
    );
    await _pumpEditor(tester, user: user, controller: controller);

    await tester.tap(find.byType(UserAvatarView));
    await tester.pumpAndSettle();

    expect(find.text('Выбрать из галереи'), findsOneWidget);
    expect(find.text('Сделать фото'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(preparationCalls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('gallery selection shows loading and blocks repeated taps', (
    tester,
  ) async {
    final preparation = Completer<PreparedAvatarImages?>();
    final sources = <AvatarReplacementSource>[];
    final controller = AvatarReplacementController.withInvokers(
      prepare: (source) {
        sources.add(source);
        return preparation.future;
      },
      replace: _unexpectedReplacement,
    );
    await _pumpEditor(tester, user: user, controller: controller);

    await tester.tap(find.byType(UserAvatarView));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать из галереи'));
    await tester.pump();

    expect(sources, [AvatarReplacementSource.gallery]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(UserAvatarView), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Выбрать из галереи'), findsNothing);
    expect(sources, hasLength(1));

    preparation.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('camera selection uses the camera source', (tester) async {
    AvatarReplacementSource? selectedSource;
    final controller = AvatarReplacementController.withInvokers(
      prepare: (source) async {
        selectedSource = source;
        return null;
      },
      replace: _unexpectedReplacement,
    );
    await _pumpEditor(tester, user: user, controller: controller);

    await tester.tap(find.byType(UserAvatarView));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сделать фото'));
    await tester.pumpAndSettle();

    expect(selectedSource, AvatarReplacementSource.camera);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('success updates the already loaded user locally', (
    tester,
  ) async {
    final newAvatar = _avatar(version: 2);
    final prepared = await tester.runAsync(() => _createPrepared(sourceFile));
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async => prepared!,
      replace: ({required uid, required images}) async => newAvatar,
    );
    await _pumpEditor(tester, user: user, controller: controller);

    await tester.tap(find.byType(UserAvatarView));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать из галереи'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    final avatarView = tester.widget<UserAvatarView>(
      find.byType(UserAvatarView),
    );
    expect(avatarView.user.effectiveAvatar, same(newAvatar));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('failure keeps the old avatar and shows a clear message', (
    tester,
  ) async {
    final oldAvatar = _avatar(version: 1);
    final oldUser = AppUser(
      uid: user.uid,
      email: user.email,
      name: user.name,
      phone: user.phone,
      about: user.about,
      avatar: oldAvatar,
    );
    final prepared = await tester.runAsync(() => _createPrepared(sourceFile));
    final controller = AvatarReplacementController.withInvokers(
      prepare: (_) async => prepared!,
      replace: ({required uid, required images}) async {
        throw StateError('Storage failed');
      },
    );
    await _pumpEditor(tester, user: oldUser, controller: controller);

    await tester.tap(find.byType(UserAvatarView));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сделать фото'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    final avatarView = tester.widget<UserAvatarView>(
      find.byType(UserAvatarView),
    );
    expect(avatarView.user.effectiveAvatar, same(oldAvatar));
    expect(
      find.text('Не удалось сохранить новый аватар. Старый аватар сохранён.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required AppUser user,
  required AvatarReplacementController controller,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProfileAvatarEditor(
          user: user,
          name: user.name,
          email: '',
          onNameTap: () {},
          controller: controller,
          avatarImageLoader: const _NullAvatarImageLoader(),
        ),
      ),
    ),
  );
}

final class _NullAvatarImageLoader implements AvatarImageLoader {
  const _NullAvatarImageLoader();

  @override
  Future<Uint8List?> load({
    required String path,
    required int version,
    required int maxSizeBytes,
  }) async {
    return null;
  }
}

Future<UserAvatar> _unexpectedReplacement({
  required String uid,
  required PreparedAvatarImages images,
}) {
  throw StateError('replacement must not run');
}

Future<PreparedAvatarImages> _createPrepared(File sourceFile) {
  return AvatarImageProcessor(
    compressor: _FakeCompressor(),
    cleanupInvoker: ({required workingDirectory, required filePaths}) {
      if (workingDirectory.existsSync()) {
        workingDirectory.deleteSync(recursive: true);
      }
      return Future.value(true);
    },
  ).process(sourceFile.path);
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

UserAvatar _avatar({required int version}) {
  return UserAvatar(
    thumbnail: MediaAsset(
      id: 'thumb-$version',
      provider: 'fake',
      path: 'user_avatars/user-1/v$version/thumb.jpg',
      type: 'userAvatarThumbnail',
      ownerType: 'user',
      ownerId: 'user-1',
      mimeType: 'image/jpeg',
      sizeBytes: 1200,
      version: version,
      updatedAt: DateTime.utc(2026, 7, 26),
    ),
    full: MediaAsset(
      id: 'full-$version',
      provider: 'fake',
      path: 'user_avatars/user-1/v$version/full.jpg',
      type: 'userAvatarFull',
      ownerType: 'user',
      ownerId: 'user-1',
      mimeType: 'image/jpeg',
      sizeBytes: 240000,
      version: version,
      updatedAt: DateTime.utc(2026, 7, 26),
    ),
  );
}
