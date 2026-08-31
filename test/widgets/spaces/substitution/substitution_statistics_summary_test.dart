import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/widgets/spaces/substitution/substitution_statistics_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    int month = 8,
    int monthCallCount = 0,
    List<SubstitutionShiftKind> monthShifts = const <SubstitutionShiftKind>[],
    int yearCallCount = 0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SubstitutionStatisticsSummary(
          month: month,
          monthCallCount: monthCallCount,
          monthShifts: monthShifts,
          yearCallCount: yearCallCount,
        ),
      ),
    );
  }

  testWidgets('shows month and yearly counts', (tester) async {
    await tester.pumpWidget(
      buildSubject(month: 8, monthCallCount: 4, yearCallCount: 7),
    );

    expect(find.text('Статистика'), findsOneWidget);
    expect(find.text('Август'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('За год'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('shows zero counts', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Август'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('supports five segment month range', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        monthShifts: const <SubstitutionShiftKind>[
          SubstitutionShiftKind.day,
          SubstitutionShiftKind.night,
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('supports nine segment month range', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        monthCallCount: 6,
        monthShifts: const <SubstitutionShiftKind>[
          SubstitutionShiftKind.day,
          SubstitutionShiftKind.night,
          SubstitutionShiftKind.day,
          SubstitutionShiftKind.day,
          SubstitutionShiftKind.night,
          SubstitutionShiftKind.night,
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('supports twelve segment month range', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        monthCallCount: 10,
        monthShifts: const <SubstitutionShiftKind>[
          SubstitutionShiftKind.day,
          SubstitutionShiftKind.night,
          SubstitutionShiftKind.day,
          SubstitutionShiftKind.night,
          SubstitutionShiftKind.day,
          SubstitutionShiftKind.night,
          SubstitutionShiftKind.day,
          SubstitutionShiftKind.night,
          SubstitutionShiftKind.day,
          SubstitutionShiftKind.night,
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
