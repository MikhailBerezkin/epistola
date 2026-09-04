import 'dart:async';

import 'package:epistola/domain/models/epistola_system_message.dart';
import 'package:epistola/services/system_chat/epistola_system_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes user id for load', () async {
    String? requestedUserId;

    final service = EpistolaSystemChatService(
      loader: ({required String userId}) async {
        requestedUserId = userId;

        return const <EpistolaSystemMessage>[];
      },
      watcher: ({required String userId}) {
        return const Stream<List<EpistolaSystemMessage>>.empty();
      },
    );

    final messages = await service.load(userId: ' user-1 ');

    expect(requestedUserId, 'user-1');
    expect(messages, isEmpty);
  });

  test('normalizes user id for realtime watch', () async {
    String? requestedUserId;

    final controller = StreamController<List<EpistolaSystemMessage>>();

    final service = EpistolaSystemChatService(
      loader: ({required String userId}) async {
        return const <EpistolaSystemMessage>[];
      },
      watcher: ({required String userId}) {
        requestedUserId = userId;

        return controller.stream;
      },
    );

    final firstFuture = service.watch(userId: ' user-1 ').first;

    controller.add(const <EpistolaSystemMessage>[]);

    await firstFuture;

    expect(requestedUserId, 'user-1');

    await controller.close();
  });

  test('rejects empty user id', () {
    final service = EpistolaSystemChatService(
      loader: ({required String userId}) async {
        return const <EpistolaSystemMessage>[];
      },
      watcher: ({required String userId}) {
        return const Stream<List<EpistolaSystemMessage>>.empty();
      },
    );

    expect(() => service.watch(userId: '   '), throwsArgumentError);
  });
}
