import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
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

  static Future<void> initialize() async {
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
        _handleRemoteMessageTap(initialMessage);
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
      payload: message.data['chatId'] as String?,
    );
  }

  static void _handleRemoteMessageTap(RemoteMessage message) {
    debugPrint('Notification opened: chatId=${message.data['chatId']}');
  }

  static void _handleLocalNotificationTap(NotificationResponse response) {
    debugPrint('Local notification opened: chatId=${response.payload}');
  }

  static Future<void> vibrate() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 80);
    }
  }
}
