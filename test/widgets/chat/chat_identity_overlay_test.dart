import 'package:epistola/widgets/chat/chat_identity_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const childKey = Key('identity-card-child');

  Widget buildTestApp({required bool isOpen}) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ChatIdentityOverlay(
              isOpen: isOpen,
              onClose: () {},
              child: const SizedBox(
                key: childKey,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets(
    'mounts identity content lazily and keeps it mounted after first open',
    (tester) async {
      await tester.pumpWidget(buildTestApp(isOpen: false));

      expect(find.byKey(childKey), findsNothing);

      await tester.pumpWidget(buildTestApp(isOpen: true));
      await tester.pump();

      expect(find.byKey(childKey), findsOneWidget);

      await tester.pumpWidget(buildTestApp(isOpen: false));
      await tester.pumpAndSettle();

      expect(find.byKey(childKey), findsOneWidget);
    },
  );
}
