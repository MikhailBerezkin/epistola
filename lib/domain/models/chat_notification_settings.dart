import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatNotificationMode { sound, silent, disabled }

class ChatNotificationSettings {
  const ChatNotificationSettings({
    required this.mode,
    this.expiresAt,
    this.permanent = false,
  });

  const ChatNotificationSettings.sound()
    : mode = ChatNotificationMode.sound,
      expiresAt = null,
      permanent = false;

  const ChatNotificationSettings.disabled()
    : mode = ChatNotificationMode.disabled,
      expiresAt = null,
      permanent = false;

  const ChatNotificationSettings.silentForever()
    : mode = ChatNotificationMode.silent,
      expiresAt = null,
      permanent = true;

  final ChatNotificationMode mode;
  final DateTime? expiresAt;
  final bool permanent;

  factory ChatNotificationSettings.silentUntil(DateTime expiresAt) {
    return ChatNotificationSettings(
      mode: ChatNotificationMode.silent,
      expiresAt: expiresAt,
    );
  }

  bool get isSound {
    return mode == ChatNotificationMode.sound;
  }

  bool get isSilent {
    return mode == ChatNotificationMode.silent;
  }

  bool get isDisabled {
    return mode == ChatNotificationMode.disabled;
  }

  bool isSilentAt(DateTime now) {
    if (!isSilent) {
      return false;
    }

    if (permanent) {
      return true;
    }

    final effectiveExpiresAt = expiresAt;

    if (effectiveExpiresAt == null) {
      return false;
    }

    return effectiveExpiresAt.isAfter(now);
  }

  ChatNotificationMode effectiveModeAt(DateTime now) {
    if (isDisabled) {
      return ChatNotificationMode.disabled;
    }

    if (isSilentAt(now)) {
      return ChatNotificationMode.silent;
    }

    return ChatNotificationMode.sound;
  }

  Map<String, dynamic> toFirestore() {
    switch (mode) {
      case ChatNotificationMode.sound:
        return <String, dynamic>{'mode': 'sound'};

      case ChatNotificationMode.disabled:
        return <String, dynamic>{'mode': 'disabled'};

      case ChatNotificationMode.silent:
        if (permanent) {
          return <String, dynamic>{'mode': 'silent', 'permanent': true};
        }

        final effectiveExpiresAt = expiresAt;

        if (effectiveExpiresAt == null) {
          return <String, dynamic>{'mode': 'sound'};
        }

        return <String, dynamic>{
          'mode': 'silent',
          'expiresAt': Timestamp.fromDate(effectiveExpiresAt),
        };
    }
  }

  static ChatNotificationSettings fromChatData({
    required Map<String, dynamic> chatData,
    required String userId,
    DateTime? now,
  }) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return const ChatNotificationSettings.sound();
    }

    final rawSettings = chatData['notificationSettingsByUser'];

    if (rawSettings is! Map) {
      return const ChatNotificationSettings.sound();
    }

    final rawUserSettings = rawSettings[normalizedUserId];

    if (rawUserSettings is! Map) {
      return const ChatNotificationSettings.sound();
    }

    final mode = rawUserSettings['mode'];

    if (mode == 'disabled') {
      return const ChatNotificationSettings.disabled();
    }

    if (mode != 'silent') {
      return const ChatNotificationSettings.sound();
    }

    if (rawUserSettings['permanent'] == true) {
      return const ChatNotificationSettings.silentForever();
    }

    final rawExpiresAt = rawUserSettings['expiresAt'];

    DateTime? expiresAt;

    if (rawExpiresAt is Timestamp) {
      expiresAt = rawExpiresAt.toDate();
    } else if (rawExpiresAt is DateTime) {
      expiresAt = rawExpiresAt;
    }

    if (expiresAt == null) {
      return const ChatNotificationSettings.sound();
    }

    final settings = ChatNotificationSettings.silentUntil(expiresAt);

    final effectiveNow = now ?? DateTime.now();

    if (!settings.isSilentAt(effectiveNow)) {
      return const ChatNotificationSettings.sound();
    }

    return settings;
  }
}
