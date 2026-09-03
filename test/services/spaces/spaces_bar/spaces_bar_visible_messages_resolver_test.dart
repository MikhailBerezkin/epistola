import 'package:epistola/domain/models/spaces_bar_board.dart';
import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_visible_messages_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = SpacesBarVisibleMessagesResolver();

  test('removes expired messages', () {
    final now = DateTime.utc(2026, 9, 3, 12);

    final board = _board([
      _message(
        id: '1',
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      _message(
        id: '2',
        lifetime: SpacesBarMessageLifetime.twelveHours,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);

    final result = resolver.resolve(
      board: board,
      hiddenMessageIds: const <String>{},
      now: now,
    );

    expect(result.map((message) => message.id), <String>['2']);
  });

  test('removes locally hidden messages', () {
    final now = DateTime.utc(2026, 9, 3, 12);

    final board = _board([
      _message(
        id: '1',
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdAt: now,
      ),
      _message(
        id: '2',
        lifetime: SpacesBarMessageLifetime.twelveHours,
        createdAt: now,
      ),
    ]);

    final result = resolver.resolve(
      board: board,
      hiddenMessageIds: const <String>{'1'},
      now: now,
    );

    expect(result.map((message) => message.id), <String>['2']);
  });

  test('sorts shorter lifetime before longer lifetime', () {
    final now = DateTime.utc(2026, 9, 3, 12);

    final board = _board([
      _message(
        id: '1',
        lifetime: SpacesBarMessageLifetime.untilCancelled,
        createdAt: now,
      ),
      _message(
        id: '2',
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdAt: now,
      ),
      _message(
        id: '3',
        lifetime: SpacesBarMessageLifetime.twentyFourHours,
        createdAt: now,
      ),
    ]);

    final result = resolver.resolve(
      board: board,
      hiddenMessageIds: const <String>{},
      now: now,
    );

    expect(result.map((message) => message.id), <String>['2', '3', '1']);
  });

  test('places twelve hours between one and twenty four hours', () {
    final now = DateTime.utc(2026, 9, 3, 12);

    final board = _board([
      _message(
        id: '1',
        lifetime: SpacesBarMessageLifetime.twentyFourHours,
        createdAt: now,
      ),
      _message(
        id: '2',
        lifetime: SpacesBarMessageLifetime.twelveHours,
        createdAt: now,
      ),
      _message(
        id: '3',
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdAt: now,
      ),
    ]);

    final result = resolver.resolve(
      board: board,
      hiddenMessageIds: const <String>{},
      now: now,
    );

    expect(result.map((message) => message.id), <String>['3', '2', '1']);
  });

  test('sorts newer messages first inside same lifetime', () {
    final now = DateTime.utc(2026, 9, 3, 12);

    final board = _board([
      _message(
        id: '1',
        lifetime: SpacesBarMessageLifetime.twelveHours,
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
      _message(
        id: '2',
        lifetime: SpacesBarMessageLifetime.twelveHours,
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      _message(
        id: '3',
        lifetime: SpacesBarMessageLifetime.twelveHours,
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
    ]);

    final result = resolver.resolve(
      board: board,
      hiddenMessageIds: const <String>{},
      now: now,
    );

    expect(result.map((message) => message.id), <String>['2', '3', '1']);
  });

  test('uses newer revision as deterministic tie breaker', () {
    final now = DateTime.utc(2026, 9, 3, 12);

    final board = _board([
      _message(
        id: '9',
        lifetime: SpacesBarMessageLifetime.untilCancelled,
        createdAt: now,
      ),
      _message(
        id: '10',
        lifetime: SpacesBarMessageLifetime.untilCancelled,
        createdAt: now,
      ),
    ]);

    final result = resolver.resolve(
      board: board,
      hiddenMessageIds: const <String>{},
      now: now,
    );

    expect(result.map((message) => message.id), <String>['10', '9']);
  });

  test('can return empty result when every active message is hidden', () {
    final now = DateTime.utc(2026, 9, 3, 12);

    final board = _board([
      _message(
        id: '1',
        lifetime: SpacesBarMessageLifetime.untilCancelled,
        createdAt: now,
      ),
    ]);

    final result = resolver.resolve(
      board: board,
      hiddenMessageIds: const <String>{'1'},
      now: now,
    );

    expect(result, isEmpty);
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
