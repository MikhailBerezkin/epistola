import 'package:epistola/services/chat/active_chat_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActiveChatTracker', () {
    test('starts without an active chat', () {
      final tracker = ActiveChatTracker();

      expect(tracker.currentChatId, isNull);
      expect(tracker.isCurrent('chat-a'), isFalse);
    });

    test('marks an entered chat as current', () {
      final tracker = ActiveChatTracker();

      tracker.enter('chat-a');

      expect(tracker.currentChatId, 'chat-a');
      expect(tracker.isCurrent('chat-a'), isTrue);
      expect(tracker.isCurrent('chat-b'), isFalse);
    });

    test('restores the previous chat after the top chat leaves', () {
      final tracker = ActiveChatTracker();

      final firstRegistration = tracker.enter('chat-a');
      final secondRegistration = tracker.enter('chat-b');

      expect(tracker.currentChatId, 'chat-b');

      tracker.leave(secondRegistration);

      expect(tracker.currentChatId, 'chat-a');

      tracker.leave(firstRegistration);

      expect(tracker.currentChatId, isNull);
    });

    test('leaving an older registration keeps the top chat active', () {
      final tracker = ActiveChatTracker();

      final firstRegistration = tracker.enter('chat-a');

      tracker.enter('chat-b');
      tracker.leave(firstRegistration);

      expect(tracker.currentChatId, 'chat-b');
    });

    test('supports repeated registrations for the same chat', () {
      final tracker = ActiveChatTracker();

      final firstRegistration = tracker.enter('chat-a');
      final secondRegistration = tracker.enter('chat-a');

      tracker.leave(secondRegistration);

      expect(tracker.currentChatId, 'chat-a');

      tracker.leave(firstRegistration);

      expect(tracker.currentChatId, isNull);
    });

    test('normalizes surrounding whitespace', () {
      final tracker = ActiveChatTracker();

      tracker.enter('  chat-a  ');

      expect(tracker.currentChatId, 'chat-a');
      expect(tracker.isCurrent(' chat-a '), isTrue);
    });

    test('rejects an empty chat ID', () {
      final tracker = ActiveChatTracker();

      expect(() => tracker.enter('   '), throwsArgumentError);
    });

    test('rejects a chat ID containing a slash', () {
      final tracker = ActiveChatTracker();

      expect(() => tracker.enter('chat/a'), throwsArgumentError);
    });
  });
}
