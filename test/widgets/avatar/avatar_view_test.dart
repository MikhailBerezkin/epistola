import 'package:cached_network_image/cached_network_image.dart';
import 'package:epistola/widgets/avatar/avatar_fallback.dart';
import 'package:epistola/widgets/avatar/avatar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows fallback when image URL is absent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarView(
            stableKey: 'user-1',
            name: 'Иван Петров',
            email: 'ivan@example.com',
            radius: 24,
          ),
        ),
      ),
    );

    expect(find.byType(AvatarFallback), findsOneWidget);
    expect(find.text('ИП'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('shows fallback when image URL is blank', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarView(
            stableKey: 'user-2',
            name: 'Анна Смирнова',
            email: 'anna@example.com',
            radius: 24,
            imageUrl: '   ',
          ),
        ),
      ),
    );

    expect(find.byType(AvatarFallback), findsOneWidget);
    expect(find.text('АС'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('configures cached network image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(devicePixelRatio: 2),
          child: Scaffold(
            body: AvatarView(
              stableKey: 'user-3',
              name: 'Борис Петров',
              email: 'boris@example.com',
              radius: 24,
              imageUrl: 'https://example.com/avatar.jpg',
              cacheKey: 'user-avatar:user-3:v7:thumb',
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );

    expect(image.imageUrl, 'https://example.com/avatar.jpg');
    expect(image.cacheKey, 'user-avatar:user-3:v7:thumb');
    expect(image.width, 48);
    expect(image.height, 48);
    expect(image.memCacheWidth, 96);
    expect(image.memCacheHeight, 96);
    expect(image.maxWidthDiskCache, 96);
    expect(image.maxHeightDiskCache, 96);
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('clips the image into a circle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarView(
            stableKey: 'user-4',
            name: 'Мария Иванова',
            email: 'maria@example.com',
            radius: 32,
            imageUrl: 'https://example.com/avatar.jpg',
            cacheKey: 'user-avatar:user-4:v8:thumb',
          ),
        ),
      ),
    );

    expect(find.byType(ClipOval), findsOneWidget);

    final clipOval = tester.widget<ClipOval>(find.byType(ClipOval));

    final sizeBox = clipOval.child! as SizedBox;

    expect(sizeBox.width, 64);
    expect(sizeBox.height, 64);
  });
}
