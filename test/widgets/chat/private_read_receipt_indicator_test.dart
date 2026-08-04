import 'package:epistola/widgets/chat/private_read_receipt_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivateReadReceiptIndicator', () {
    Future<void> pumpIndicator(WidgetTester tester, {required bool isRead}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PrivateReadReceiptIndicator(isRead: isRead)),
        ),
      );
    }

    testWidgets('shows one check for a saved message', (tester) async {
      await pumpIndicator(tester, isRead: false);

      expect(find.text('✓'), findsOneWidget);
      expect(find.text('✓✓'), findsNothing);
    });

    testWidgets('shows two checks for a read message', (tester) async {
      await pumpIndicator(tester, isRead: true);

      expect(find.text('✓'), findsNothing);
      expect(find.text('✓✓'), findsOneWidget);
    });

    testWidgets('provides accessible labels for both states', (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      try {
        await pumpIndicator(tester, isRead: false);

        expect(find.bySemanticsLabel('Сообщение сохранено'), findsOneWidget);

        await pumpIndicator(tester, isRead: true);

        expect(find.bySemanticsLabel('Сообщение прочитано'), findsOneWidget);
      } finally {
        semanticsHandle.dispose();
      }
    });
  });
}
