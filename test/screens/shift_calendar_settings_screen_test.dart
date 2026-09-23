import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/screens/shift_calendar_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows current crew as selected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ShiftCalendarSettingsScreen(initialCrew: ShiftCrew.crew4),
      ),
    );

    expect(find.text('Просмотр звена'), findsOneWidget);
    expect(find.text('4 звено'), findsOneWidget);

    final selectedIcon = find.byIcon(Icons.check_circle);

    expect(selectedIcon, findsOneWidget);
  });

  testWidgets('returns selected preview crew without persistence', (
    tester,
  ) async {
    ShiftCrew? returnedCrew;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    returnedCrew = await Navigator.of(context).push<ShiftCrew>(
                      MaterialPageRoute<ShiftCrew>(
                        builder: (_) => const ShiftCalendarSettingsScreen(
                          initialCrew: ShiftCrew.crew4,
                        ),
                      ),
                    );
                  },
                  child: const Text('Открыть'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2 звено'));
    await tester.pumpAndSettle();

    expect(returnedCrew, ShiftCrew.crew2);
  });

  testWidgets('explains that preview does not change work crew', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ShiftCalendarSettingsScreen(initialCrew: ShiftCrew.crew3),
      ),
    );

    expect(
      find.textContaining('Ваше рабочее звено при этом не изменится'),
      findsOneWidget,
    );
  });
}
