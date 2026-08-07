import 'package:flutter_test/flutter_test.dart';

import 'package:epistola/models/chat_notification_settings.dart';
import 'package:epistola/services/chat/chat_notification_settings_service.dart';

void main() {
  const chatId = 'chat-1';
  const userId = 'user-1';

  final fixedNow = DateTime.utc(2026, 8, 7, 9, 0);

  test('writes sound mode for current user', () async {
    final commits = <_Commit>[];

    final service = _service(commits: commits, userId: userId, now: fixedNow);

    final result = await service.enableSound(chatId: chatId);

    expect(result, ChatNotificationSettingsWriteResult.written);

    expect(commits, hasLength(1));
    expect(commits.single.chatId, chatId);
    expect(commits.single.userId, userId);
    expect(commits.single.settings.mode, ChatNotificationMode.sound);
  });

  test('writes disabled mode for current user', () async {
    final commits = <_Commit>[];

    final service = _service(commits: commits, userId: userId, now: fixedNow);

    await service.disableNotifications(chatId: chatId);

    expect(commits.single.settings.mode, ChatNotificationMode.disabled);
  });

  test('writes permanent silent mode', () async {
    final commits = <_Commit>[];

    final service = _service(commits: commits, userId: userId, now: fixedNow);

    await service.silenceForever(chatId: chatId);

    final settings = commits.single.settings;

    expect(settings.mode, ChatNotificationMode.silent);
    expect(settings.permanent, isTrue);
    expect(settings.expiresAt, isNull);
  });

  test('writes one hour temporary silent mode', () async {
    final commits = <_Commit>[];

    final service = _service(commits: commits, userId: userId, now: fixedNow);

    await service.silenceFor(
      chatId: chatId,
      duration: const Duration(hours: 1),
    );

    final settings = commits.single.settings;

    expect(settings.mode, ChatNotificationMode.silent);
    expect(settings.permanent, isFalse);
    expect(settings.expiresAt, fixedNow.add(const Duration(hours: 1)));
  });

  test('writes 24 hour temporary silent mode', () async {
    final commits = <_Commit>[];

    final service = _service(commits: commits, userId: userId, now: fixedNow);

    await service.silenceFor(
      chatId: chatId,
      duration: const Duration(hours: 24),
    );

    expect(
      commits.single.settings.expiresAt,
      fixedNow.add(const Duration(hours: 24)),
    );
  });

  test('skips write when unauthenticated', () async {
    final commits = <_Commit>[];

    final service = _service(commits: commits, userId: null, now: fixedNow);

    final result = await service.enableSound(chatId: chatId);

    expect(result, ChatNotificationSettingsWriteResult.skippedUnauthenticated);

    expect(commits, isEmpty);
  });

  test('rejects an invalid chat id', () {
    final service = _service(
      commits: <_Commit>[],
      userId: userId,
      now: fixedNow,
    );

    expect(() => service.enableSound(chatId: 'bad/chat'), throwsArgumentError);
  });

  test('rejects temporary silent mode longer than 24 hours', () {
    final service = _service(
      commits: <_Commit>[],
      userId: userId,
      now: fixedNow,
    );

    expect(
      () => service.silenceFor(
        chatId: chatId,
        duration: const Duration(hours: 25),
      ),
      throwsArgumentError,
    );
  });
}

ChatNotificationSettingsService _service({
  required List<_Commit> commits,
  required String? userId,
  required DateTime now,
}) {
  return ChatNotificationSettingsService(
    userIdProvider: () => userId,
    nowProvider: () => now,
    settingsCommitter:
        ({
          required String chatId,
          required String userId,
          required ChatNotificationSettings settings,
        }) async {
          commits.add(
            _Commit(chatId: chatId, userId: userId, settings: settings),
          );
        },
  );
}

class _Commit {
  const _Commit({
    required this.chatId,
    required this.userId,
    required this.settings,
  });

  final String chatId;
  final String userId;
  final ChatNotificationSettings settings;
}
