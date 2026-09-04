import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epistola/widgets/system_chat/epistola_system_chat_tile.dart';

void main() {
  testWidgets('shows Epistola technical chat presentation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EpistolaSystemChatTile(onTap: () {})),
      ),
    );

    expect(find.byKey(const Key('epistola-system-chat-tile')), findsOneWidget);
    expect(find.text('Epistola'), findsOneWidget);
    expect(find.text('Технические сообщения'), findsOneWidget);

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('epistola-system-chat-avatar')),
    );

    expect(avatar.radius, 20);

    final image = avatar.backgroundImage;

    expect(image, isA<AssetImage>());
    expect(
      (image! as AssetImage).assetName,
      EpistolaSystemChatTile.avatarAsset,
    );
  });

  testWidgets('calls onTap', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpistolaSystemChatTile(
            onTap: () {
              tapCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('epistola-system-chat-tile')));

    expect(tapCount, 1);
  });
}
