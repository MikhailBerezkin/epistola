import 'package:epistola/models/app_user.dart';
import 'package:epistola/widgets/avatar/user_avatar_view.dart';
import 'package:epistola/widgets/chat_app_bar_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const peerUser = AppUser(
    uid: 'peer-user-id',
    email: 'boris@example.com',
    name: 'Борис Иванов',
    phone: '',
    about: '',
  );

  Widget buildSubject({
    AppUser? user,
    bool isGroup = false,
    String chatName = 'Борис Иванов',
  }) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: ChatAppBarTitle(
            chatName: chatName,
            subtitle: isGroup ? '3 участников' : 'личный чат',
            peerUser: user,
            isGroup: isGroup,
          ),
        ),
      ),
    );
  }

  testWidgets('uses UserAvatarView for a private chat with peer user', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(user: peerUser));

    expect(find.byType(UserAvatarView), findsOneWidget);
  });

  testWidgets('keeps CircleAvatar for a group chat', (tester) async {
    await tester.pumpWidget(
      buildSubject(user: peerUser, isGroup: true, chatName: 'Рабочая группа'),
    );

    expect(find.byType(UserAvatarView), findsNothing);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('Р'), findsOneWidget);
  });

  testWidgets('keeps fallback when private peer user is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byType(UserAvatarView), findsNothing);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('Б'), findsOneWidget);
  });
}
