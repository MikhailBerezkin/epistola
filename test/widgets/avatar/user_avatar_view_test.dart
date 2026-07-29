import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/domain/models/user_avatar.dart';
import 'package:epistola/models/app_user.dart';
import 'package:epistola/services/avatar/avatar_image_loader.dart';
import 'package:epistola/services/avatar/avatar_image_pipeline_config.dart';
import 'package:epistola/widgets/avatar/avatar_fallback.dart';
import 'package:epistola/widgets/avatar/user_avatar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the thumbnail through the authenticated path loader', (
    tester,
  ) async {
    final user = _userWithAvatar();
    final loader = _FakeAvatarImageLoader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserAvatarView(user: user, radius: 24, imageLoader: loader),
        ),
      ),
    );
    await tester.pump();

    expect(loader.calls.single.path, 'user_avatars/user-1/v3/thumb.jpg');
    expect(loader.calls.single.version, 3);
    expect(
      loader.calls.single.maxSizeBytes,
      AvatarImagePipelineConfig.hardThumbnailSizeBytes,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('loads the full image with the 512 KB cap', (tester) async {
    final user = _userWithAvatar();
    final loader = _FakeAvatarImageLoader();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserAvatarView(
            user: user,
            radius: 48,
            imageVariant: UserAvatarImageVariant.full,
            imageLoader: loader,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(loader.calls.single.path, 'user_avatars/user-1/v3/full.jpg');
    expect(loader.calls.single.version, 3);
    expect(
      loader.calls.single.maxSizeBytes,
      AvatarImagePipelineConfig.hardFullSizeBytes,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('shows fallback when the user has no avatar', (tester) async {
    const user = AppUser(
      uid: 'user-2',
      email: 'anna@example.com',
      name: 'Анна Смирнова',
      phone: '',
      about: '',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserAvatarView(user: user, radius: 24)),
      ),
    );

    expect(find.byType(AvatarFallback), findsOneWidget);
    expect(find.text('АС'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('supports legacy avatarUrl without a versioned cache key', (
    tester,
  ) async {
    const user = AppUser(
      uid: 'legacy-user',
      email: 'legacy@example.com',
      name: 'Старый Пользователь',
      phone: '',
      about: '',
      avatarUrl: 'https://example.com/legacy.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserAvatarView(user: user, radius: 24)),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.imageUrl, 'https://example.com/legacy.jpg');
    expect(image.cacheKey, isNull);
  });

  testWidgets('shows the stable fallback when stored JPEG bytes are corrupt', (
    tester,
  ) async {
    final user = _userWithAvatar(name: 'Ada Lovelace');
    final loader = _FakeAvatarImageLoader(
      bytes: Uint8List.fromList(const [0xff, 0xd8, 0xff, 0x00]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserAvatarView(user: user, radius: 24, imageLoader: loader),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(AvatarFallback), findsOneWidget);
    expect(find.text('AL'), findsOneWidget);
    final corruptImageFallbackColor = tester
        .widget<CircleAvatar>(find.byType(CircleAvatar))
        .backgroundColor;

    const userWithoutAvatar = AppUser(
      uid: 'user-1',
      email: 'ivan@example.com',
      name: 'Ada Lovelace',
      phone: '',
      about: '',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatarView(user: userWithoutAvatar, radius: 24),
        ),
      ),
    );

    expect(find.text('AL'), findsOneWidget);
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor,
      corruptImageFallbackColor,
    );
  });
}

final class _FakeAvatarImageLoader implements AvatarImageLoader {
  _FakeAvatarImageLoader({Uint8List? bytes})
    : _bytes =
          bytes ??
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
            'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          );

  final List<_LoadCall> calls = [];
  final Uint8List _bytes;

  @override
  Future<Uint8List?> load({
    required String path,
    required int version,
    required int maxSizeBytes,
  }) async {
    calls.add(
      _LoadCall(path: path, version: version, maxSizeBytes: maxSizeBytes),
    );
    return _bytes;
  }
}

final class _LoadCall {
  const _LoadCall({
    required this.path,
    required this.version,
    required this.maxSizeBytes,
  });

  final String path;
  final int version;
  final int maxSizeBytes;
}

AppUser _userWithAvatar({String name = 'Иван Петров'}) {
  return AppUser(
    uid: 'user-1',
    email: 'ivan@example.com',
    name: name,
    phone: '',
    about: '',
    avatar: UserAvatar(
      thumbnail: const MediaAsset(
        id: 'user-1-avatar-v3-thumb',
        provider: 'firebase',
        path: 'user_avatars/user-1/v3/thumb.jpg',
        type: 'userAvatarThumbnail',
        ownerType: 'user',
        ownerId: 'user-1',
        mimeType: 'image/jpeg',
        width: 128,
        height: 128,
        version: 3,
        downloadUrl: 'https://example.com/thumb.jpg',
      ),
      full: const MediaAsset(
        id: 'user-1-avatar-v3-full',
        provider: 'firebase',
        path: 'user_avatars/user-1/v3/full.jpg',
        type: 'userAvatarFull',
        ownerType: 'user',
        ownerId: 'user-1',
        mimeType: 'image/jpeg',
        width: 512,
        height: 512,
        version: 3,
        downloadUrl: 'https://example.com/full.jpg',
      ),
    ),
  );
}
