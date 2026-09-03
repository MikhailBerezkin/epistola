import 'package:epistola/domain/models/spaces_bar_board.dart';
import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_presentation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 3, 12);

  test(
    'keeps locally hidden messages active but removes them from presentation',
    () async {
      final board = _board([
        _message(
          id: '1',
          lifetime: SpacesBarMessageLifetime.untilCancelled,
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        _message(
          id: '2',
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
      ]);

      final service = SpacesBarPresentationService(
        boardLoader: () async => board,
        hiddenMessageIdsLoader: ({required String userId}) async {
          return <String>{'2'};
        },
        messageHider:
            ({required String userId, required String messageId}) async {},
        clock: () => now,
      );

      final state = await service.load(userId: 'user-1');

      expect(state.activeMessages.map((message) => message.id), <String>[
        '1',
        '2',
      ]);

      expect(state.visibleMessages.map((message) => message.id), <String>['1']);

      expect(state.hiddenMessageIds, <String>{'2'});
      expect(state.activeMessageCount, 2);
      expect(state.hasVisibleMessages, isTrue);
    },
  );

  test('removes expired messages from active and visible state', () async {
    final board = _board([
      _message(
        id: '1',
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      _message(
        id: '2',
        lifetime: SpacesBarMessageLifetime.untilCancelled,
        createdAt: now,
      ),
    ]);

    final service = SpacesBarPresentationService(
      boardLoader: () async => board,
      hiddenMessageIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      messageHider:
          ({required String userId, required String messageId}) async {},
      clock: () => now,
    );

    final state = await service.load(userId: 'user-1');

    expect(state.activeMessages.map((message) => message.id), <String>['2']);

    expect(state.visibleMessages.map((message) => message.id), <String>['2']);
  });

  test('hideMessage persists local hide without reloading board', () async {
    var boardLoadCount = 0;
    String? hiddenUserId;
    String? hiddenMessageId;

    final board = _board([
      _message(
        id: '1',
        lifetime: SpacesBarMessageLifetime.untilCancelled,
        createdAt: now,
      ),
      _message(
        id: '2',
        lifetime: SpacesBarMessageLifetime.untilCancelled,
        createdAt: now,
      ),
    ]);

    final service = SpacesBarPresentationService(
      boardLoader: () async {
        boardLoadCount += 1;
        return board;
      },
      hiddenMessageIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      messageHider:
          ({required String userId, required String messageId}) async {
            hiddenUserId = userId;
            hiddenMessageId = messageId;
          },
      clock: () => now,
    );

    final initialState = await service.load(userId: ' user-1 ');

    final nextState = await service.hideMessage(
      userId: ' user-1 ',
      messageId: ' 2 ',
      currentState: initialState,
    );

    expect(boardLoadCount, 1);

    expect(hiddenUserId, 'user-1');
    expect(hiddenMessageId, '2');

    expect(nextState.activeMessages.map((message) => message.id), <String>[
      '1',
      '2',
    ]);

    expect(nextState.visibleMessages.map((message) => message.id), <String>[
      '1',
    ]);

    expect(nextState.hiddenMessageIds, <String>{'2'});
  });

  test('hideMessage does not mutate previous presentation state', () async {
    final board = _board([
      _message(
        id: '1',
        lifetime: SpacesBarMessageLifetime.untilCancelled,
        createdAt: now,
      ),
    ]);

    final service = SpacesBarPresentationService(
      boardLoader: () async => board,
      hiddenMessageIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      messageHider:
          ({required String userId, required String messageId}) async {},
      clock: () => now,
    );

    final initialState = await service.load(userId: 'user-1');

    final nextState = await service.hideMessage(
      userId: 'user-1',
      messageId: '1',
      currentState: initialState,
    );

    expect(initialState.hiddenMessageIds, isEmpty);
    expect(initialState.visibleMessages, hasLength(1));

    expect(nextState.hiddenMessageIds, <String>{'1'});
    expect(nextState.visibleMessages, isEmpty);
    expect(nextState.hasVisibleMessages, isFalse);
  });

  test('presentation hidden ids cannot be mutated externally', () async {
    final board = _board([
      _message(
        id: '1',
        lifetime: SpacesBarMessageLifetime.untilCancelled,
        createdAt: now,
      ),
    ]);

    final service = SpacesBarPresentationService(
      boardLoader: () async => board,
      hiddenMessageIdsLoader: ({required String userId}) async {
        return <String>{'1'};
      },
      messageHider:
          ({required String userId, required String messageId}) async {},
      clock: () => now,
    );

    final state = await service.load(userId: 'user-1');

    expect(() => state.hiddenMessageIds.add('2'), throwsUnsupportedError);
  });
}

SpacesBarBoard _board(List<SpacesBarMessage> messages) {
  final board = SpacesBarBoard.tryCreate(revision: 10, messages: messages);

  expect(board, isNotNull);

  return board!;
}

SpacesBarMessage _message({
  required String id,
  required SpacesBarMessageLifetime lifetime,
  required DateTime createdAt,
}) {
  final message = SpacesBarMessage.tryCreate(
    id: id,
    text: 'Сообщение $id',
    lifetime: lifetime,
    createdByUserId: 'owner-1',
    createdAt: createdAt,
  );

  expect(message, isNotNull);

  return message!;
}
