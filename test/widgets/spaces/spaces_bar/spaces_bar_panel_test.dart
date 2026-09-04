import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/domain/models/substitution_confirmed_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_presentation_item.dart';
import 'package:epistola/widgets/spaces/spaces_bar/spaces_bar_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows neutral state when there are no items', (tester) async {
    await tester.pumpWidget(
      _app(const SpacesBarPanel(items: <SpacesBarPresentationItem>[])),
    );

    expect(find.text('Нет новых закреплённых сообщений'), findsOneWidget);
    expect(find.byKey(const Key('spaces-bar-empty-seagull')), findsOneWidget);
  });

  testWidgets('keeps requested general target when newer item arrives', (
    tester,
  ) async {
    const rotationInterval = Duration(hours: 1);

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          targetMessageId: '9',
          items: <SpacesBarPresentationItem>[_generalItem(id: '9')],
          autoRotationInterval: rotationInterval,
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-9'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          targetMessageId: '9',
          items: <SpacesBarPresentationItem>[
            _substitutionItem(callId: '10'),
            _generalItem(id: '9'),
          ],
          autoRotationInterval: rotationInterval,
        ),
      ),
    );

    await tester.pump();

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-9'),
      findsOneWidget,
    );
  });

  testWidgets('general target does not match same-numbered substitution call', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          targetMessageId: '7',
          items: <SpacesBarPresentationItem>[
            _substitutionItem(callId: '7'),
            _generalItem(id: '7'),
          ],
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-7'),
      findsOneWidget,
    );
  });

  testWidgets('shows newly added general item immediately', (tester) async {
    const rotationInterval = Duration(hours: 1);

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[
            _generalItem(id: '2'),
            _generalItem(id: '1'),
          ],
          autoRotationInterval: rotationInterval,
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-2'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[
            _generalItem(id: '3'),
            _generalItem(id: '2'),
            _generalItem(id: '1'),
          ],
          autoRotationInterval: rotationInterval,
        ),
      ),
    );

    await tester.pump();

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-3'),
      findsOneWidget,
    );
  });

  testWidgets('shows newly added personal call immediately', (tester) async {
    const rotationInterval = Duration(hours: 1);

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[_generalItem(id: '7')],
          autoRotationInterval: rotationInterval,
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-7'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[
            _substitutionItem(callId: '7'),
            _generalItem(id: '7'),
          ],
          autoRotationInterval: rotationInterval,
        ),
      ),
    );

    await tester.pump();

    expect(
      find.bySemanticsLabel('spaces-bar-current-substitution-call-7'),
      findsOneWidget,
    );
  });

  testWidgets('shows general message without lifetime label', (tester) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[
            _generalItem(
              id: '1',
              text: 'Важное сообщение',
              lifetime: SpacesBarMessageLifetime.oneHour,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Важное сообщение'), findsOneWidget);

    expect(find.text('1 час'), findsNothing);
  });

  testWidgets('personal call uses purple accent', (tester) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[_substitutionItem(callId: '7')],
        ),
      ),
    );

    final card = tester.widget<Card>(
      find.byKey(const ValueKey('spaces-bar-substitution-call-7')),
    );

    final shape = card.shape as RoundedRectangleBorder;

    expect(shape.side.color, Colors.purple);
  });

  testWidgets('shows dots for mixed items', (tester) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[
            _generalItem(id: '1'),
            _substitutionItem(callId: '2'),
            _generalItem(id: '3'),
          ],
        ),
      ),
    );

    expect(find.byKey(const ValueKey('spaces-bar-dot-0')), findsOneWidget);

    expect(find.byKey(const ValueKey('spaces-bar-dot-1')), findsOneWidget);

    expect(find.byKey(const ValueKey('spaces-bar-dot-2')), findsOneWidget);
  });

  testWidgets('opens requested general target', (tester) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          targetMessageId: '2',
          items: <SpacesBarPresentationItem>[
            _generalItem(id: '1'),
            _generalItem(id: '2'),
            _generalItem(id: '3'),
          ],
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-2'),
      findsOneWidget,
    );
  });

  testWidgets('opens requested target after items are loaded', (tester) async {
    await tester.pumpWidget(
      _app(
        const SpacesBarPanel(
          items: <SpacesBarPresentationItem>[],
          targetMessageId: '2',
        ),
      ),
    );

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          targetMessageId: '2',
          items: <SpacesBarPresentationItem>[
            _generalItem(id: '1'),
            _generalItem(id: '2'),
            _generalItem(id: '3'),
          ],
        ),
      ),
    );

    await tester.pump();

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-2'),
      findsOneWidget,
    );
  });

  testWidgets('automatically rotates between mixed items', (tester) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          autoRotationInterval: const Duration(seconds: 1),
          items: <SpacesBarPresentationItem>[
            _generalItem(id: '1'),
            _substitutionItem(callId: '2'),
          ],
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-1'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));

    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.bySemanticsLabel('spaces-bar-current-substitution-call-2'),
      findsOneWidget,
    );
  });

  testWidgets('long press can locally hide general message', (tester) async {
    String? hiddenMessageId;

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[_generalItem(id: '7')],
          onHideMessage: (messageId) async {
            hiddenMessageId = messageId;
          },
        ),
      ),
    );

    await tester.longPress(find.byKey(const ValueKey('spaces-bar-message-7')));

    await tester.pumpAndSettle();

    expect(find.text('Убрать сообщение'), findsOneWidget);

    await tester.tap(find.text('Убрать сообщение'));

    await tester.pumpAndSettle();

    expect(hiddenMessageId, '7');
  });

  testWidgets('long press personal call uses separate hide callback', (
    tester,
  ) async {
    String? hiddenCallId;
    String? hiddenMessageId;

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[_substitutionItem(callId: '7')],
          onHideMessage: (messageId) async {
            hiddenMessageId = messageId;
          },
          onHideSubstitutionCall: (callId) async {
            hiddenCallId = callId;
          },
        ),
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey('spaces-bar-substitution-call-7')),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Убрать сообщение'));

    await tester.pumpAndSettle();

    expect(hiddenCallId, '7');

    expect(hiddenMessageId, isNull);
  });

  testWidgets('shows details only when general text overflows', (tester) async {
    final longText = List<String>.filled(
      8,
      'Длинное закреплённое сообщение',
    ).join(' ');

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: SpacesBarPanel(
            items: <SpacesBarPresentationItem>[
              _generalItem(id: '1', text: longText),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Подробнее'), findsOneWidget);

    await tester.tap(find.text('Подробнее'));

    await tester.pumpAndSettle();

    expect(find.text('Закреплённое сообщение'), findsOneWidget);

    expect(find.text('Закрыть'), findsOneWidget);
  });

  testWidgets('personal details do not show fake lifetime', (tester) async {
    final longText = List<String>.filled(
      8,
      'Вы вызваны на дневную смену',
    ).join(' ');

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: SpacesBarPanel(
            items: <SpacesBarPresentationItem>[
              _substitutionItem(callId: '7', text: longText),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Подробнее'));

    await tester.pumpAndSettle();

    expect(find.text('Вызов на смену'), findsOneWidget);

    expect(find.text('До отмены'), findsNothing);

    expect(find.text('1 час'), findsNothing);
  });

  testWidgets('legacy messages input remains supported during migration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(SpacesBarPanel(messages: <SpacesBarMessage>[_message(id: '5')])),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-5'),
      findsOneWidget,
    );
  });

  testWidgets('new general item surfaces immediately after personal item', (
    tester,
  ) async {
    const rotationInterval = Duration(hours: 1);

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[_substitutionItem(callId: '7')],
          autoRotationInterval: rotationInterval,
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-substitution-call-7'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[
            _generalItem(id: '8'),
            _substitutionItem(callId: '7'),
          ],
          autoRotationInterval: rotationInterval,
        ),
      ),
    );

    await tester.pump();

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-8'),
      findsOneWidget,
    );
  });

  testWidgets('new item restarts full rotation interval', (tester) async {
    const rotationInterval = Duration(seconds: 1);

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[
            _generalItem(id: '1'),
            _generalItem(id: '2'),
          ],
          autoRotationInterval: rotationInterval,
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-1'),
      findsOneWidget,
    );

    // Старый интервал уже прошёл больше половины.
    await tester.pump(const Duration(milliseconds: 600));

    // Приходит новый personal item.
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          items: <SpacesBarPresentationItem>[
            _substitutionItem(callId: '3'),
            _generalItem(id: '1'),
            _generalItem(id: '2'),
          ],
          autoRotationInterval: rotationInterval,
        ),
      ),
    );

    await tester.pump();

    expect(
      find.bySemanticsLabel('spaces-bar-current-substitution-call-3'),
      findsOneWidget,
    );

    // Если старый Timer не был сброшен,
    // через оставшиеся 400 ms карточка бы уже ушла.
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.bySemanticsLabel('spaces-bar-current-substitution-call-3'),
      findsOneWidget,
    );

    // Теперь проходит уже полный новый интервал.
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-1'),
      findsOneWidget,
    );
  });

  testWidgets('personal item joins ordinary rotation after being surfaced', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          autoRotationInterval: const Duration(seconds: 1),
          items: <SpacesBarPresentationItem>[
            _substitutionItem(callId: '3'),
            _generalItem(id: '2'),
            _generalItem(id: '1'),
          ],
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-substitution-call-3'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));

    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-2'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));

    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-1'),
      findsOneWidget,
    );
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

SpacesBarPresentationItem _generalItem({
  required String id,
  String? text,
  SpacesBarMessageLifetime lifetime = SpacesBarMessageLifetime.untilCancelled,
}) {
  return SpacesBarPresentationItem.general(
    message: _message(id: id, text: text, lifetime: lifetime),
  );
}

SpacesBarPresentationItem _substitutionItem({
  required String callId,
  String text = 'Вы вызваны на дневную смену 05.09.2026 в 08:00',
}) {
  final revision = int.parse(callId);

  final call = SubstitutionConfirmedCall(
    callId: callId,
    userId: 'user-1',
    revision: revision,
    calledByUserId: 'brigadier-1',
    calledAt: DateTime.utc(2026, 9, 4, 10),
    finalizedAt: DateTime.utc(2026, 9, 4, 10, 0, 6),
    shift: SubstitutionShift(
      year: 2026,
      month: 9,
      day: 5,
      kind: SubstitutionShiftKind.day,
    ),
  );

  return SpacesBarPresentationItem.substitution(call: call, text: text);
}

SpacesBarMessage _message({
  required String id,
  String? text,
  SpacesBarMessageLifetime lifetime = SpacesBarMessageLifetime.untilCancelled,
}) {
  final message = SpacesBarMessage.tryCreate(
    id: id,
    text: text ?? 'Сообщение $id',
    lifetime: lifetime,
    createdByUserId: 'owner-1',
    createdAt: DateTime.utc(2026, 9, 3, 12),
  );

  expect(message, isNotNull);

  return message!;
}
