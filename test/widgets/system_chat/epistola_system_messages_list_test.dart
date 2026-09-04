import 'package:epistola/domain/models/epistola_system_message.dart';
import 'package:epistola/widgets/system_chat/epistola_system_messages_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows messages with time and date separators', (tester) async {
    final now = DateTime(2026, 9, 4, 20);

    final messages = [
      EpistolaSystemMessage(
        id: 'substitutionCall:1',
        source: EpistolaSystemMessageSource.substitutionCall,
        sourceId: '1',
        text: 'Первое сообщение',
        createdAt: DateTime(2026, 9, 3, 18, 42),
      ),
      EpistolaSystemMessage(
        id: 'substitutionCall:2',
        source: EpistolaSystemMessageSource.substitutionCall,
        sourceId: '2',
        text: 'Второе сообщение',
        createdAt: DateTime(2026, 9, 3, 19, 5),
      ),
      EpistolaSystemMessage(
        id: 'substitutionCall:3',
        source: EpistolaSystemMessageSource.substitutionCall,
        sourceId: '3',
        text: 'Третье сообщение',
        createdAt: DateTime(2026, 9, 4, 7, 8),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpistolaSystemMessagesList(messages: messages, now: now),
        ),
      ),
    );

    expect(find.text('Первое сообщение'), findsOneWidget);

    expect(find.text('Второе сообщение'), findsOneWidget);

    expect(find.text('Третье сообщение'), findsOneWidget);

    expect(find.text('Вчера'), findsOneWidget);

    expect(find.text('Сегодня'), findsOneWidget);

    expect(find.text('18:42'), findsOneWidget);

    expect(find.text('19:05'), findsOneWidget);

    expect(find.text('07:08'), findsOneWidget);
  });

  testWidgets('contains no message input or interactive message actions', (
    tester,
  ) async {
    final message = EpistolaSystemMessage(
      id: 'substitutionCall:7',
      source: EpistolaSystemMessageSource.substitutionCall,
      sourceId: '7',
      text: 'Техническое сообщение',
      createdAt: DateTime(2026, 9, 4, 12),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpistolaSystemMessagesList(
            messages: [message],
            now: DateTime(2026, 9, 4, 13),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);

    expect(find.byType(TextFormField), findsNothing);

    expect(find.byType(IconButton), findsNothing);

    expect(
      find.byKey(const ValueKey('epistola-system-message-substitutionCall:7')),
      findsOneWidget,
    );
  });
}
