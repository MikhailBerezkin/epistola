import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/screens/assigned_crew_setup_screen.dart';
import 'package:epistola/services/work_schedule/user_assigned_crew_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('save button is disabled until crew is selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssignedCrewSetupScreen(userId: 'user-1', service: _service()),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Сохранить звено'),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('shows confirmation for selected crew', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssignedCrewSetupScreen(userId: 'user-1', service: _service()),
      ),
    );

    await tester.tap(find.text('4'));
    await tester.pump();

    await tester.tap(find.text('Сохранить звено'));
    await tester.pumpAndSettle();

    expect(find.text('Подтвердить звено?'), findsOneWidget);
    expect(find.textContaining('Вы выбрали 4 звено.'), findsOneWidget);
    expect(
      find.textContaining('самостоятельно изменить звено будет нельзя'),
      findsOneWidget,
    );
  });

  testWidgets('cancel does not write assigned crew', (tester) async {
    var writeCount = 0;

    final service = UserAssignedCrewService(
      assignedCrewWriter:
          ({required String userId, required int crewNumber}) async {
            writeCount++;
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AssignedCrewSetupScreen(userId: 'user-1', service: service),
      ),
    );

    await tester.tap(find.text('2'));
    await tester.pump();

    await tester.tap(find.text('Сохранить звено'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(writeCount, 0);
  });

  testWidgets('confirmation writes selected assigned crew', (tester) async {
    String? writtenUserId;
    int? writtenCrewNumber;

    final service = UserAssignedCrewService(
      assignedCrewWriter:
          ({required String userId, required int crewNumber}) async {
            writtenUserId = userId;
            writtenCrewNumber = crewNumber;
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AssignedCrewSetupScreen(userId: ' user-1 ', service: service),
      ),
    );

    await tester.tap(find.text('3'));
    await tester.pump();

    await tester.tap(find.text('Сохранить звено'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();

    expect(writtenUserId, 'user-1');
    expect(writtenCrewNumber, ShiftCrew.crew3.number);
  });

  testWidgets('required setup disables back and reports saved crew', (
    tester,
  ) async {
    ShiftCrew? savedCrew;

    await tester.pumpWidget(
      MaterialApp(
        home: AssignedCrewSetupScreen(
          userId: 'user-1',
          allowBack: false,
          onSaved: (crew) {
            savedCrew = crew;
          },
          service: _service(),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(appBar.automaticallyImplyLeading, isFalse);

    await tester.tap(find.text('4'));
    await tester.pump();

    await tester.tap(find.text('Сохранить звено'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();

    expect(savedCrew, ShiftCrew.crew4);
  });
}

UserAssignedCrewService _service() {
  return UserAssignedCrewService(
    assignedCrewWriter:
        ({required String userId, required int crewNumber}) async {},
  );
}
