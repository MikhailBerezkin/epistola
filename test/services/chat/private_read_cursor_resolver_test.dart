import 'package:epistola/services/chat/private_read_cursor_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivateReadCursorResolver', () {
    final firstTime = DateTime.utc(2026, 8, 3, 16);
    final secondTime = DateTime.utc(2026, 8, 3, 16, 1);
    final thirdTime = DateTime.utc(2026, 8, 3, 16, 2);

    test('returns null for an empty collection', () {
      final result = PrivateReadCursorResolver.fromChronologicalCandidates(
        const <PrivateReadCursorCandidate>[],
      );

      expect(result, isNull);
    });

    test('returns the last visible chronological candidate', () {
      final result = PrivateReadCursorResolver.fromChronologicalCandidates([
        (messageId: 'message-1', messageCreatedAt: firstTime, isVisible: true),
        (messageId: 'message-2', messageCreatedAt: secondTime, isVisible: true),
      ]);

      expect(result, isNotNull);
      expect(result!.messageId, 'message-2');
      expect(result.messageCreatedAt, secondTime);
    });

    test('ignores a hidden final candidate', () {
      final result = PrivateReadCursorResolver.fromChronologicalCandidates([
        (messageId: 'message-1', messageCreatedAt: firstTime, isVisible: true),
        (
          messageId: 'message-2',
          messageCreatedAt: secondTime,
          isVisible: false,
        ),
      ]);

      expect(result, isNotNull);
      expect(result!.messageId, 'message-1');
    });

    test('ignores multiple invisible candidates', () {
      final result = PrivateReadCursorResolver.fromChronologicalCandidates([
        (messageId: 'message-1', messageCreatedAt: firstTime, isVisible: false),
        (messageId: 'message-2', messageCreatedAt: secondTime, isVisible: true),
        (messageId: 'message-3', messageCreatedAt: thirdTime, isVisible: false),
      ]);

      expect(result, isNotNull);
      expect(result!.messageId, 'message-2');
    });

    test('ignores a candidate without a timestamp', () {
      final result = PrivateReadCursorResolver.fromChronologicalCandidates([
        (messageId: 'message-1', messageCreatedAt: firstTime, isVisible: true),
        (messageId: 'message-2', messageCreatedAt: null, isVisible: true),
      ]);

      expect(result, isNotNull);
      expect(result!.messageId, 'message-1');
    });

    test('ignores a candidate with an invalid message ID', () {
      final result = PrivateReadCursorResolver.fromChronologicalCandidates([
        (messageId: 'message-1', messageCreatedAt: firstTime, isVisible: true),
        (messageId: 'message/2', messageCreatedAt: secondTime, isVisible: true),
      ]);

      expect(result, isNotNull);
      expect(result!.messageId, 'message-1');
    });

    test('returns null when no valid visible candidate exists', () {
      final result = PrivateReadCursorResolver.fromChronologicalCandidates([
        (messageId: 'message-1', messageCreatedAt: firstTime, isVisible: false),
        (messageId: 'message-2', messageCreatedAt: null, isVisible: true),
        (messageId: 'message/3', messageCreatedAt: thirdTime, isVisible: true),
      ]);

      expect(result, isNull);
    });
  });
}
