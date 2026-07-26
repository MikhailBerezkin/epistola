import 'package:cached_network_image/cached_network_image.dart';
import 'package:epistola/domain/models/media_asset.dart';
import 'package:epistola/domain/models/user_avatar.dart';
import 'package:epistola/models/app_user.dart';
import 'package:epistola/widgets/avatar/avatar_fallback.dart';
import 'package:epistola/widgets/avatar/user_avatar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses thumbnail URL and cache key by default', (tester) async {
    final user = _userWithAvatar();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UserAvatarView(user: user, radius: 24)),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.imageUrl, 'https://example.com/thumb.jpg');
    expect(image.cacheKey, 'user-avatar:user-1:v3:thumb');
  });

  testWidgets('uses full image when requested', (tester) async {
    final user = _userWithAvatar();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserAvatarView(
            user: user,
            radius: 48,
            imageVariant: UserAvatarImageVariant.full,
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.imageUrl, 'https://example.com/full.jpg');
    expect(image.cacheKey, 'user-avatar:user-1:v3:full');
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
}

AppUser _userWithAvatar() {
  return AppUser(
    uid: 'user-1',
    email: 'ivan@example.com',
    name: 'Иван Петров',
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
