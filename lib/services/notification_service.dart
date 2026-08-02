import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../domain/models/push_deep_link_request.dart';
import 'push/push_deep_link_coordinator.dart';
import 'push_token_service.dart';

class NotificationService {
  static const AndroidNotificationChannel _messageChannel =
      AndroidNotificationChannel(
        'epistola_messages',
        'Сообщения Epistola',
        description: 'Уведомления о новых сообщениях',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static PushDeepLinkCoordinator? _deepLinkCoordinator;

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
  }

  static Future<void> startMessaging() async {
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
          'Notification permission: ${settings.authorizationStatus.name}',
        );
      }

      final token = await FirebaseMessaging.instance.getToken();

      if (kDebugMode) {
        debugPrint(
          token == null ? 'FCM token is unavailable' : 'FCM token received',
        );
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        if (kDebugMode) {
          debugPrint('FCM token refreshed');
        }
      });

      FirebaseMessaging.onMessage.listen(showForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);

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
    final android = notification?.android;

    if (notification == null || android == null) {
      return;
    }

    final request = PushDeepLinkRequest.fromRemoteData(message.data);

    await _localNotifications.show(
      id: message.messageId.hashCode & 0x7fffffff,
      title: notification.title ?? 'Epistola',
      body: notification.body ?? 'Новое сообщение',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _messageChannel.id,
          _messageChannel.name,
          channelDescription: _messageChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: request?.chatId,
    );
  }

  static Future<void> _handleRemoteMessageTap(RemoteMessage message) async {
    final request = PushDeepLinkRequest.fromRemoteData(message.data);

    if (request == null) {
      if (kDebugMode) {
        debugPrint('Remote notification has no valid chatId');
      }

      return;
    }

    await _handleDeepLinkRequest(request);
  }

  static void _handleLocalNotificationTap(NotificationResponse response) {
    final request = PushDeepLinkRequest.fromLocalPayload(response.payload);

    if (request == null) {
      if (kDebugMode) {
        debugPrint('Local notification has no valid chatId');
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
        debugPrint(
          'Push deep link coordinator is unavailable: '
          'chatId=${request.chatId}',
        );
      }

      return;
    }

    if (kDebugMode) {
      debugPrint('Opening notification chat: chatId=${request.chatId}');
    }

    await coordinator.handle(request);
  }

  static Future<void> vibrate() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 80);
    }
  }
}
