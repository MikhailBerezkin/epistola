import 'package:epistola/widgets/avatar/avatar_fallback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows first and last name initials', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarFallback(
            stableKey: 'user-1',
            name: 'Иван Петров',
            email: 'ivan@example.com',
            radius: 24,
          ),
        ),
      ),
    );

    expect(find.text('ИП'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('falls back to the email initial', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarFallback(
            stableKey: 'user-2',
            name: '',
            email: 'boriska@example.com',
            radius: 24,
          ),
        ),
      ),
    );

    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('uses the requested radius', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarFallback(
            stableKey: 'user-3',
            name: 'Анна Смирнова',
            email: 'anna@example.com',
            radius: 32,
          ),
        ),
      ),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));

    expect(avatar.radius, 32);
  });

  testWidgets('uses stable colors for the same key', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AvatarFallback(
                stableKey: 'user-42',
                name: 'Первый пользователь',
                email: 'first@example.com',
                radius: 24,
              ),
              AvatarFallback(
                stableKey: 'user-42',
                name: 'Другое имя',
                email: 'second@example.com',
                radius: 24,
              ),
            ],
          ),
        ),
      ),
    );

    final avatars = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .toList();

    expect(avatars, hasLength(2));
    expect(avatars[0].backgroundColor, avatars[1].backgroundColor);
    expect(avatars[0].foregroundColor, avatars[1].foregroundColor);
  });
}
