import 'package:epistola/models/app_user.dart';
import 'package:epistola/widgets/avatar/user_avatar_view.dart';
import 'package:epistola/widgets/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the full user avatar variant', (tester) async {
    const user = AppUser(
      uid: 'user-1',
      email: 'ivan@example.com',
      name: 'Иван Петров',
      phone: '',
      about: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileHeader(
            avatarUser: user,
            name: user.name,
            email: '',
            onNameTap: () {},
          ),
        ),
      ),
    );

    final avatar = tester.widget<UserAvatarView>(find.byType(UserAvatarView));

    expect(avatar.user, same(user));
    expect(avatar.radius, 48);
    expect(avatar.imageVariant, UserAvatarImageVariant.full);
    expect(find.text('ИП'), findsOneWidget);
  });

  testWidgets('calls callback when the name is tapped', (tester) async {
    var tapped = false;

    const user = AppUser(
      uid: 'user-2',
      email: 'anna@example.com',
      name: 'Анна Смирнова',
      phone: '',
      about: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileHeader(
            avatarUser: user,
            name: user.name,
            email: '',
            onNameTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Анна Смирнова'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('hides an empty email subtitle', (tester) async {
    const user = AppUser(
      uid: 'user-3',
      email: 'hidden@example.com',
      name: 'Мария Иванова',
      phone: '',
      about: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileHeader(
            avatarUser: user,
            name: user.name,
            email: '',
            onNameTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('hidden@example.com'), findsNothing);
  });
}
