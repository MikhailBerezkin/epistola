import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/widgets/work_schedule/assigned_crew_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows all four crews', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssignedCrewSelector(selectedCrew: null, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.text('Ваше звено'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('reports selected crew', (tester) async {
    ShiftCrew? selectedCrew;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssignedCrewSelector(
            selectedCrew: null,
            onChanged: (crew) {
              selectedCrew = crew;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('4'));
    await tester.pump();

    expect(selectedCrew, ShiftCrew.crew4);
  });

  testWidgets('shows current selection', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssignedCrewSelector(
            selectedCrew: ShiftCrew.crew3,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final segmentedButton = tester.widget<SegmentedButton<ShiftCrew>>(
      find.byType(SegmentedButton<ShiftCrew>),
    );

    expect(segmentedButton.selected, {ShiftCrew.crew3});
  });

  testWidgets('disabled selector does not change crew', (tester) async {
    ShiftCrew? selectedCrew;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssignedCrewSelector(
            selectedCrew: ShiftCrew.crew2,
            enabled: false,
            onChanged: (crew) {
              selectedCrew = crew;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('4'));
    await tester.pump();

    expect(selectedCrew, isNull);
  });
}
