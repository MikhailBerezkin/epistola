import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/widgets/spaces/spaces_bar/spaces_bar_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows neutral state when there are no messages', (tester) async {
    await tester.pumpWidget(
      _app(const SpacesBarPanel(messages: <SpacesBarMessage>[])),
    );

    expect(find.text('Нет новых закреплённых сообщений'), findsOneWidget);
  });

  testWidgets('keeps requested target when a newer message arrives', (
    tester,
  ) async {
    const rotationInterval = Duration(hours: 1);

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          targetMessageId: '9',
          messages: <SpacesBarMessage>[_message(id: '9')],
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
          messages: <SpacesBarMessage>[
            _message(id: '10'),
            _message(id: '9'),
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

  testWidgets('shows newly added message immediately', (tester) async {
    const rotationInterval = Duration(hours: 1);

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          messages: <SpacesBarMessage>[
            _message(id: '2'),
            _message(id: '1'),
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
          messages: <SpacesBarMessage>[
            _message(id: '3'),
            _message(id: '2'),
            _message(id: '1'),
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

  testWidgets('shows message without lifetime label', (tester) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          messages: <SpacesBarMessage>[
            _message(
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

  testWidgets('shows dots for multiple messages', (tester) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          messages: <SpacesBarMessage>[
            _message(id: '1'),
            _message(id: '2'),
            _message(id: '3'),
          ],
        ),
      ),
    );

    expect(find.byKey(const ValueKey('spaces-bar-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('spaces-bar-dot-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('spaces-bar-dot-2')), findsOneWidget);
  });

  testWidgets('opens requested target message', (tester) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          targetMessageId: '2',
          messages: <SpacesBarMessage>[
            _message(id: '1'),
            _message(id: '2'),
            _message(id: '3'),
          ],
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('spaces-bar-current-message-2'),
      findsOneWidget,
    );
  });

  testWidgets('opens requested target after messages are loaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SpacesBarPanel(
          messages: <SpacesBarMessage>[],
          targetMessageId: '2',
        ),
      ),
    );

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          targetMessageId: '2',
          messages: <SpacesBarMessage>[
            _message(id: '1'),
            _message(id: '2'),
            _message(id: '3'),
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

  testWidgets('automatically rotates to next message', (tester) async {
    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          autoRotationInterval: const Duration(seconds: 1),
          messages: <SpacesBarMessage>[
            _message(id: '1'),
            _message(id: '2'),
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
      find.bySemanticsLabel('spaces-bar-current-message-2'),
      findsOneWidget,
    );
  });

  testWidgets('long press can locally hide message', (tester) async {
    String? hiddenMessageId;

    await tester.pumpWidget(
      _app(
        SpacesBarPanel(
          messages: <SpacesBarMessage>[_message(id: '7')],
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

  testWidgets('shows details only when text overflows', (tester) async {
    final longText = List<String>.filled(
      8,
      'Длинное закреплённое сообщение',
    ).join(' ');

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: SpacesBarPanel(
            messages: <SpacesBarMessage>[_message(id: '1', text: longText)],
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
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
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
