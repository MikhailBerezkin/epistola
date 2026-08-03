import 'package:epistola/widgets/chat/chat_date_separator.dart';
import 'package:epistola/widgets/chat/chat_scroll_date_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('ChatDateSeparator', () {
    testWidgets('shows the provided date label', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ChatDateSeparator(label: '3 августа')),
      );

      expect(find.text('3 августа'), findsOneWidget);
    });
  });

  group('ChatScrollDateIndicator', () {
    testWidgets('is visible when label exists and visibility is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const ChatScrollDateIndicator(label: 'Сегодня', isVisible: true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Сегодня'), findsOneWidget);

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );

      expect(animatedOpacity.opacity, 1);
    });

    testWidgets('fades out when visibility is disabled', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ChatScrollDateIndicator(label: 'Вчера', isVisible: true),
        ),
      );

      await tester.pumpAndSettle();

      await tester.pumpWidget(
        buildTestApp(
          const ChatScrollDateIndicator(label: 'Вчера', isVisible: false),
        ),
      );

      await tester.pumpAndSettle();

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );

      expect(animatedOpacity.opacity, 0);
    });

    testWidgets('animates when the displayed date changes', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ChatScrollDateIndicator(label: '2 августа', isVisible: true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('2 августа'), findsOneWidget);

      await tester.pumpWidget(
        buildTestApp(
          const ChatScrollDateIndicator(label: '3 августа', isVisible: true),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('2 августа'), findsNothing);
      expect(find.text('3 августа'), findsOneWidget);
    });
  });
}
