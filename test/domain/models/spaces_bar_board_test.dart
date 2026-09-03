import 'package:epistola/domain/models/spaces_bar_board.dart';
import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpacesBarBoard', () {
    final createdAt = DateTime.utc(2026, 9, 3, 10);

    SpacesBarMessage message({
      required String id,
      SpacesBarMessageLifetime lifetime = SpacesBarMessageLifetime.twelveHours,
      DateTime? createdAtOverride,
    }) {
      return SpacesBarMessage.tryCreate(
        id: id,
        text: 'Сообщение $id',
        lifetime: lifetime,
        createdByUserId: 'brigadier-1',
        createdAt: createdAtOverride ?? createdAt,
      )!;
    }

    test('creates empty board', () {
      final board = SpacesBarBoard.empty();

      expect(board.revision, 0);
      expect(board.messages, isEmpty);
    });

    test('creates board with up to three messages', () {
      final board = SpacesBarBoard.tryCreate(
        revision: 7,
        messages: [
          message(id: 'message-1'),
          message(id: 'message-2'),
          message(id: 'message-3'),
        ],
      );

      expect(board, isNotNull);
      expect(board!.revision, 7);
      expect(board.messages, hasLength(3));
    });

    test('rejects more than three messages', () {
      final board = SpacesBarBoard.tryCreate(
        revision: 1,
        messages: [
          message(id: 'message-1'),
          message(id: 'message-2'),
          message(id: 'message-3'),
          message(id: 'message-4'),
        ],
      );

      expect(board, isNull);
    });

    test('rejects negative revision', () {
      final board = SpacesBarBoard.tryCreate(revision: -1, messages: const []);

      expect(board, isNull);
    });

    test('rejects duplicate message ids', () {
      final board = SpacesBarBoard.tryCreate(
        revision: 1,
        messages: [
          message(id: 'message-1'),
          message(id: 'message-1'),
        ],
      );

      expect(board, isNull);
    });

    test('messages list cannot be mutated through source list', () {
      final source = [message(id: 'message-1')];

      final board = SpacesBarBoard.tryCreate(revision: 1, messages: source)!;

      source.add(message(id: 'message-2'));

      expect(board.messages, hasLength(1));
    });

    test('returns only messages active at requested time', () {
      final board = SpacesBarBoard.tryCreate(
        revision: 1,
        messages: [
          message(id: 'expired', lifetime: SpacesBarMessageLifetime.oneHour),
          message(
            id: 'active',
            lifetime: SpacesBarMessageLifetime.twentyFourHours,
          ),
          message(
            id: 'persistent',
            lifetime: SpacesBarMessageLifetime.untilCancelled,
          ),
        ],
      )!;

      final active = board.activeMessagesAt(
        createdAt.add(const Duration(hours: 2)),
      );

      expect(active.map((message) => message.id), ['active', 'persistent']);
    });

    test('expired message does not consume active capacity', () {
      final board = SpacesBarBoard.tryCreate(
        revision: 1,
        messages: [
          message(id: 'expired', lifetime: SpacesBarMessageLifetime.oneHour),
          message(
            id: 'active-1',
            lifetime: SpacesBarMessageLifetime.twentyFourHours,
          ),
          message(
            id: 'active-2',
            lifetime: SpacesBarMessageLifetime.untilCancelled,
          ),
        ],
      )!;

      expect(
        board.hasCapacityAt(createdAt.add(const Duration(hours: 2))),
        isTrue,
      );
    });

    test('three active messages consume all capacity', () {
      final board = SpacesBarBoard.tryCreate(
        revision: 1,
        messages: [
          message(id: 'message-1'),
          message(id: 'message-2'),
          message(id: 'message-3'),
        ],
      )!;

      expect(
        board.hasCapacityAt(createdAt.add(const Duration(hours: 1))),
        isFalse,
      );
    });
  });
}
