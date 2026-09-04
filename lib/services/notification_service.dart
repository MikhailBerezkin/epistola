import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../domain/models/push_deep_link_request.dart';
import 'chat/active_chat_tracker.dart';
import 'push/push_deep_link_coordinator.dart';
import 'push_token_service.dart';

class NotificationService {
  static final AndroidNotificationChannel _messageChannel =
      AndroidNotificationChannel(
        'epistola_messages_seagull_v3',
        'Сообщения Epistola — Чайка',
        description: 'Уведомления о новых сообщениях',
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(
          'seagull_notification',
        ),
        enableVibration: true,
        vibrationPattern: Int64List.fromList(<int>[0, 250, 100, 250]),
      );

  static final AndroidNotificationChannel _spacesBarChannel =
      AndroidNotificationChannel(
        'epistola_spaces_bar_v1',
        'Объявления Epistola',
        description: 'Важные объявления из Пространств',
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(
          'seagull_notification',
        ),
        enableVibration: true,
        vibrationPattern: Int64List.fromList(<int>[0, 250, 100, 250]),
      );

  static const AndroidNotificationChannel _silentMessageChannel =
      AndroidNotificationChannel(
        'epistola_messages_silent',
        'Тихие сообщения Epistola',
        description: 'Уведомления без звука и вибрации',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
      );

  static const String _silentNotificationMode = 'silent';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static PushDeepLinkCoordinator? _deepLinkCoordinator;
  static bool _messagingListenersStarted = false;

  static Future<void> initialize({
    required PushDeepLinkCoordinator deepLinkCoordinator,
  }) async {
    _deepLinkCoordinator = deepLinkCoordinator;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_messageChannel);

    await androidPlugin?.createNotificationChannel(_silentMessageChannel);

    await androidPlugin?.createNotificationChannel(_spacesBarChannel);
  }

  static Future<void> startMessaging() async {
    if (!_messagingListenersStarted) {
      _messagingListenersStarted = true;

      FirebaseMessaging.onMessage.listen((message) {
        unawaited(showForegroundMessage(message));
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        unawaited(_handleRemoteMessageTap(message));
      });
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      await PushTokenService.initialize();

      if (kDebugMode) {
        debugPrint(
          'Notification permission: '
          '${settings.authorizationStatus.name}',
        );
      }

      try {
        final token = await FirebaseMessaging.instance.getToken();

        if (kDebugMode) {
          debugPrint(
            token == null ? 'FCM token is unavailable' : 'FCM token received',
          );
        }
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('FCM token read error: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();

      if (initialMessage != null) {
        await _handleRemoteMessageTap(initialMessage);
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Notification setup error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) {
      return;
    }

    final request = PushDeepLinkRequest.fromRemoteData(message.data);
    final chatId = request?.chatId;

    if (chatId != null && activeChatTracker.isCurrent(chatId)) {
      if (kDebugMode) {
        debugPrint(
          'Foreground notification suppressed for active chat: '
          'chatId=$chatId',
        );
      }

      return;
    }

    final isSilent =
        message.data['notificationMode'] == _silentNotificationMode;

    final channel = request?.isSpacesBar == true
        ? _spacesBarChannel
        : isSilent
        ? _silentMessageChannel
        : _messageChannel;

    await _localNotifications.show(
      id: message.messageId.hashCode & 0x7fffffff,
      title: notification.title ?? 'Epistola',
      body: notification.body ?? 'Новое сообщение',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: request?.isSpacesBar == true || !isSilent,
          sound: isSilent && request?.isSpacesBar != true
              ? null
              : const RawResourceAndroidNotificationSound(
                  'seagull_notification',
                ),
          enableVibration: request?.isSpacesBar == true || !isSilent,
        ),
      ),
      payload: request?.toLocalPayload(),
    );
    if (!isSilent) {
      await vibrate();
    }
  }

  static Future<void> _handleRemoteMessageTap(RemoteMessage message) async {
    final request = PushDeepLinkRequest.fromRemoteData(message.data);

    if (request == null) {
      if (kDebugMode) {
        debugPrint('Remote notification has no valid deep link target');
      }

      return;
    }

    await _handleDeepLinkRequest(request);
  }

  static void _handleLocalNotificationTap(NotificationResponse response) {
    final request = PushDeepLinkRequest.fromLocalPayload(response.payload);

    if (request == null) {
      if (kDebugMode) {
        debugPrint('Local notification has no valid deep link target');
      }

      return;
    }

    unawaited(_handleDeepLinkRequest(request));
  }

  static Future<void> _handleDeepLinkRequest(
    PushDeepLinkRequest request,
  ) async {
    final coordinator = _deepLinkCoordinator;

    if (coordinator == null) {
      if (kDebugMode) {
        debugPrint('Push deep link coordinator is unavailable: $request');
      }

      return;
    }

    if (kDebugMode) {
      debugPrint('Opening notification target: $request');
    }

    await coordinator.handle(request);
  }

  static Future<void> vibrate() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 80);
    }
  }
}
