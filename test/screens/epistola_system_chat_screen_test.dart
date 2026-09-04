import 'dart:async';

import 'package:epistola/domain/models/epistola_system_message.dart';
import 'package:epistola/screens/epistola_system_chat_screen.dart';
import 'package:epistola/services/system_chat/epistola_system_chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows loading and then empty state', (tester) async {
    String? watchedUserId;

    final controller = StreamController<List<EpistolaSystemMessage>>();

    addTearDown(controller.close);

    final service = EpistolaSystemChatService(
      loader: ({required String userId}) async {
        return const <EpistolaSystemMessage>[];
      },
      watcher: ({required String userId}) {
        watchedUserId = userId;

        return controller.stream;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EpistolaSystemChatScreen(service: service, userId: ' user-1 '),
      ),
    );

    expect(find.text('Epistola'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('epistola-system-chat-loading')),
      findsOneWidget,
    );

    expect(watchedUserId, 'user-1');

    controller.add(const <EpistolaSystemMessage>[]);

    await tester.pump();

    expect(
      find.byKey(const ValueKey('epistola-system-chat-empty')),
      findsOneWidget,
    );

    expect(find.text('Технических сообщений пока нет'), findsOneWidget);
  });

  testWidgets('shows realtime system messages without composer', (
    tester,
  ) async {
    final controller = StreamController<List<EpistolaSystemMessage>>();

    addTearDown(controller.close);

    final service = _serviceFor(controller);

    await tester.pumpWidget(
      MaterialApp(
        home: EpistolaSystemChatScreen(service: service, userId: 'user-1'),
      ),
    );

    controller.add([
      _message(
        id: 'substitutionCall:1',
        text: 'Первое техническое сообщение',
        hour: 10,
      ),
    ]);

    await tester.pump();
    await tester.pump();

    expect(find.text('Первое техническое сообщение'), findsOneWidget);

    controller.add([
      _message(
        id: 'substitutionCall:1',
        text: 'Первое техническое сообщение',
        hour: 10,
      ),
      _message(
        id: 'substitutionCall:2',
        text: 'Второе техническое сообщение',
        hour: 11,
      ),
    ]);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Второе техническое сообщение'), findsOneWidget);

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('shows error state', (tester) async {
    final service = EpistolaSystemChatService(
      loader: ({required String userId}) async {
        return const <EpistolaSystemMessage>[];
      },
      watcher: ({required String userId}) {
        return Stream<List<EpistolaSystemMessage>>.error(
          StateError('test error'),
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EpistolaSystemChatScreen(service: service, userId: 'user-1'),
      ),
    );

    await tester.pump();

    expect(
      find.byKey(const ValueKey('epistola-system-chat-error')),
      findsOneWidget,
    );

    expect(
      find.text('Не удалось загрузить технические сообщения'),
      findsOneWidget,
    );

    expect(
      find.byKey(const ValueKey('epistola-system-chat-retry')),
      findsOneWidget,
    );
  });

  testWidgets('opens initially at the newest messages', (tester) async {
    final controller = StreamController<List<EpistolaSystemMessage>>();

    addTearDown(controller.close);

    final service = _serviceFor(controller);

    await tester.pumpWidget(
      MaterialApp(
        home: EpistolaSystemChatScreen(service: service, userId: 'user-1'),
      ),
    );

    controller.add(
      List<EpistolaSystemMessage>.generate(
        30,
        (index) => _message(
          id: 'substitutionCall:$index',
          text: 'Техническое сообщение $index',
          hour: index % 24,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Техническое сообщение 29'), findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );

    expect(scrollable.position.extentAfter, closeTo(0, 0.5));
  });

  testWidgets('cancels realtime listener when screen is disposed', (
    tester,
  ) async {
    var listenCount = 0;
    var cancelCount = 0;

    final controller = StreamController<List<EpistolaSystemMessage>>(
      onListen: () {
        listenCount += 1;
      },
      onCancel: () {
        cancelCount += 1;
      },
    );

    addTearDown(controller.close);

    final service = _serviceFor(controller);

    await tester.pumpWidget(
      MaterialApp(
        home: EpistolaSystemChatScreen(service: service, userId: 'user-1'),
      ),
    );

    expect(listenCount, 1);
    expect(cancelCount, 0);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    await tester.pump();

    expect(cancelCount, 1);
  });
}

EpistolaSystemChatService _serviceFor(
  StreamController<List<EpistolaSystemMessage>> controller,
) {
  return EpistolaSystemChatService(
    loader: ({required String userId}) async {
      return const <EpistolaSystemMessage>[];
    },
    watcher: ({required String userId}) {
      return controller.stream;
    },
  );
}

EpistolaSystemMessage _message({
  required String id,
  required String text,
  required int hour,
}) {
  final sourceId = id.split(':').last;

  return EpistolaSystemMessage(
    id: id,
    source: EpistolaSystemMessageSource.substitutionCall,
    sourceId: sourceId,
    text: text,
    createdAt: DateTime(2026, 9, 4, hour),
  );
}
