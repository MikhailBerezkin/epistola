import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/chat_notification_settings.dart';

typedef ChatNotificationCurrentUserIdProvider = String? Function();
typedef ChatNotificationNowProvider = DateTime Function();

typedef ChatNotificationSettingsCommitter =
    Future<void> Function({
      required String chatId,
      required String userId,
      required ChatNotificationSettings settings,
    });

enum ChatNotificationSettingsWriteResult { written, skippedUnauthenticated }

final class ChatNotificationSettingsService {
  ChatNotificationSettingsService({
    required ChatNotificationCurrentUserIdProvider userIdProvider,
    required ChatNotificationSettingsCommitter settingsCommitter,
    ChatNotificationNowProvider? nowProvider,
  }) : _currentUserIdProvider = userIdProvider,
       _commit = settingsCommitter,
       _nowProvider = nowProvider ?? DateTime.now;

  factory ChatNotificationSettingsService.firebase({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final resolvedAuth = auth ?? FirebaseAuth.instance;

    return ChatNotificationSettingsService(
      userIdProvider: () {
        return resolvedAuth.currentUser?.uid;
      },
      settingsCommitter:
          ({
            required String chatId,
            required String userId,
            required ChatNotificationSettings settings,
          }) {
            return resolvedFirestore.collection('chats').doc(chatId).update({
              'notificationSettingsByUser.$userId': settings.toFirestore(),
            });
          },
    );
  }

  static const Duration maximumTemporarySilentDuration = Duration(hours: 24);

  final ChatNotificationCurrentUserIdProvider _currentUserIdProvider;

  final ChatNotificationSettingsCommitter _commit;
  final ChatNotificationNowProvider _nowProvider;

  Future<ChatNotificationSettingsWriteResult> enableSound({
    required String chatId,
  }) {
    return _write(
      chatId: chatId,
      settings: const ChatNotificationSettings.sound(),
    );
  }

  Future<ChatNotificationSettingsWriteResult> disableNotifications({
    required String chatId,
  }) {
    return _write(
      chatId: chatId,
      settings: const ChatNotificationSettings.disabled(),
    );
  }

  Future<ChatNotificationSettingsWriteResult> silenceForever({
    required String chatId,
  }) {
    return _write(
      chatId: chatId,
      settings: const ChatNotificationSettings.silentForever(),
    );
  }

  Future<ChatNotificationSettingsWriteResult> silenceFor({
    required String chatId,
    required Duration duration,
  }) {
    if (duration <= Duration.zero ||
        duration > maximumTemporarySilentDuration) {
      throw ArgumentError.value(
        duration,
        'duration',
        'duration must be greater than zero and no longer than 24 hours.',
      );
    }

    return _write(
      chatId: chatId,
      settings: ChatNotificationSettings.silentUntil(
        _nowProvider().add(duration),
      ),
    );
  }

  Future<ChatNotificationSettingsWriteResult> _write({
    required String chatId,
    required ChatNotificationSettings settings,
  }) async {
    final normalizedChatId = _normalizeRequiredIdentifier(
      value: chatId,
      argumentName: 'chatId',
    );

    final currentUserId = _currentUserIdProvider()?.trim() ?? '';

    if (!_isValidIdentifier(currentUserId)) {
      return ChatNotificationSettingsWriteResult.skippedUnauthenticated;
    }

    await _commit(
      chatId: normalizedChatId,
      userId: currentUserId,
      settings: settings,
    );

    return ChatNotificationSettingsWriteResult.written;
  }

  static bool _isValidIdentifier(String value) {
    return value.isNotEmpty && value == value.trim() && !value.contains('/');
  }

  static String _normalizeRequiredIdentifier({
    required String value,
    required String argumentName,
  }) {
    final normalizedValue = value.trim();

    if (!_isValidIdentifier(normalizedValue)) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must be a non-empty string without slashes.',
      );
    }

    return normalizedValue;
  }
}
