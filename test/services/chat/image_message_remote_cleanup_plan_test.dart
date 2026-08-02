import 'package:epistola/services/chat/image_message_remote_cleanup_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageMessageRemoteCleanupPlan', () {
    test('builds exact thumbnail and full paths', () {
      final plan = ImageMessageRemoteCleanupPlan.tryCreate(
        chatId: 'chat-1',
        messageId: 'message-1',
        version: 3,
      );

      expect(plan, isNotNull);
      expect(
        plan!.thumbnailStoragePath,
        'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
      );
      expect(
        plan.fullStoragePath,
        'chat_media/chat-1/messages/message-1/v3/full.jpg',
      );
    });

    test('contains exactly two unique cleanup paths', () {
      final plan = ImageMessageRemoteCleanupPlan.tryCreate(
        chatId: 'chat-1',
        messageId: 'message-1',
        version: 3,
      );

      expect(plan, isNotNull);
      expect(plan!.storagePaths, hasLength(2));
      expect(plan.storagePaths.toSet(), hasLength(2));
      expect(
        plan.storagePaths,
        orderedEquals([
          'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
          'chat_media/chat-1/messages/message-1/v3/full.jpg',
        ]),
      );
    });

    test('rejects invalid identifiers and version', () {
      expect(
        ImageMessageRemoteCleanupPlan.tryCreate(
          chatId: '   ',
          messageId: 'message-1',
          version: 1,
        ),
        isNull,
      );

      expect(
        ImageMessageRemoteCleanupPlan.tryCreate(
          chatId: 'chat-1',
          messageId: '',
          version: 1,
        ),
        isNull,
      );

      expect(
        ImageMessageRemoteCleanupPlan.tryCreate(
          chatId: 'chat-1',
          messageId: 'message-1',
          version: 0,
        ),
        isNull,
      );
    });

    test('owns only the exact expected objects', () {
      final plan = ImageMessageRemoteCleanupPlan.tryCreate(
        chatId: 'chat-1',
        messageId: 'message-1',
        version: 3,
      );

      expect(plan, isNotNull);
      expect(
        plan!.ownsStoragePath(
          'chat_media/chat-1/messages/message-1/v3/thumb.jpg',
        ),
        isTrue,
      );
      expect(
        plan.ownsStoragePath(
          'chat_media/chat-1/messages/message-1/v3/full.jpg',
        ),
        isTrue,
      );
      expect(
        plan.ownsStoragePath(
          'chat_media/chat-1/messages/message-2/v3/thumb.jpg',
        ),
        isFalse,
      );
      expect(
        plan.ownsStoragePath(
          'chat_media/chat-1/messages/message-1/v2/full.jpg',
        ),
        isFalse,
      );
    });

    test('isolates different message versions', () {
      final versionThree = ImageMessageRemoteCleanupPlan.tryCreate(
        chatId: 'chat-1',
        messageId: 'message-1',
        version: 3,
      );

      final versionFour = ImageMessageRemoteCleanupPlan.tryCreate(
        chatId: 'chat-1',
        messageId: 'message-1',
        version: 4,
      );

      expect(versionThree, isNotNull);
      expect(versionFour, isNotNull);
      expect(
        versionThree!.storagePaths.toSet().intersection(
          versionFour!.storagePaths.toSet(),
        ),
        isEmpty,
      );
    });
  });
}
