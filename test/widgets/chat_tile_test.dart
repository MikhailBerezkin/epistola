import 'package:epistola/models/app_user.dart';
import 'package:epistola/widgets/avatar/user_avatar_view.dart';
import 'package:epistola/widgets/chat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const peerUser = AppUser(
    uid: 'peer-user',
    email: 'roman@example.com',
    name: 'Роман Орлов',
    phone: '',
    about: '',
  );

  testWidgets('private chat uses the peer thumbnail avatar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTile(
            chatId: 'private-chat',
            chatName: peerUser.name,
            isPrivateChat: true,
            peerUser: peerUser,
            lastMessage: 'Привет',
            lastMessageAt: null,
            unreadCountFuture: Future.value(0),
            onTap: () {},
          ),
        ),
      ),
    );

    final avatar = tester.widget<UserAvatarView>(find.byType(UserAvatarView));

    expect(avatar.user, same(peerUser));
    expect(avatar.radius, 20);
    expect(avatar.imageVariant, UserAvatarImageVariant.thumbnail);
  });

  testWidgets('private chat falls back to chatName without a peer user', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTile(
            chatId: 'private-chat',
            chatName: 'Резервное имя',
            isPrivateChat: true,
            lastMessage: '',
            lastMessageAt: null,
            unreadCountFuture: Future.value(0),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(UserAvatarView), findsNothing);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('Р'), findsOneWidget);
  });

  testWidgets('group chat keeps its existing avatar and interactions', (
    tester,
  ) async {
    var tapped = false;
    var longPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTile(
            chatId: 'group-chat',
            chatName: 'Команда',
            lastMessage: 'Сообщение',
            lastMessageAt: null,
            unreadCountFuture: Future.value(0),
            onTap: () {
              tapped = true;
            },
            onLongPress: () {
              longPressed = true;
            },
          ),
        ),
      ),
    );

    expect(find.byType(UserAvatarView), findsNothing);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('К'), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.longPress(find.byType(ListTile));

    expect(tapped, isTrue);
    expect(longPressed, isTrue);
  });
}
