import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';

import '../domain/models/push_deep_link_request.dart';
import '../domain/models/shift_alarm.dart';
import '../domain/models/shift_alarm_occurrence.dart';
import 'chat/active_chat_tracker.dart';
import 'push/push_deep_link_coordinator.dart';
import 'push_token_service.dart';

final class ShiftAlarmRingRequest {
  const ShiftAlarmRingRequest({
    required this.notificationId,
    required this.title,
    required this.ringAtMilliseconds,
  });

  final int notificationId;
  final String title;
  final int ringAtMilliseconds;

  String get requestKey => '$notificationId:$ringAtMilliseconds';
}

typedef ShiftAlarmRingHandler =
    Future<void> Function(ShiftAlarmRingRequest request);

@pragma('vm:entry-point')
Future<void> notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  await NotificationService.handleBackgroundNotificationResponse(
    notificationResponse,
  );
}

class NotificationService {
  static const String _shiftAlarmStopActionId = 'shift_alarm_stop';
  static const String _shiftAlarmSnoozeActionId = 'shift_alarm_snooze_10';

  static const Duration _shiftAlarmSnoozeDuration = Duration(minutes: 10);

  static const String _systemAlarmSoundUri =
      'content://settings/system/alarm_alert';

  static const List<AndroidNotificationAction> _shiftAlarmActions =
      <AndroidNotificationAction>[
        AndroidNotificationAction(
          _shiftAlarmStopActionId,
          'Остановить',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _shiftAlarmSnoozeActionId,
          '+10 минут',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ];

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

  static const AndroidNotificationChannel _calendarReminderChannel =
      AndroidNotificationChannel(
        'epistola_calendar_reminders_v1',
        'Напоминания календаря',
        description: 'Локальные напоминания о делах и заметках',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  // Старый канал оставляем коротким оповещениям.
  static const AndroidNotificationChannel _shiftNotificationChannel =
      AndroidNotificationChannel(
        'epistola_shift_alarms_v1',
        'Сигналы смен Epistola',
        description: 'Короткие сигналы рабочего календаря',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

  // Новый channel id нужен, потому что Android не позволяет приложению
  // заменить звук уже созданного notification channel.
  static final AndroidNotificationChannel _shiftAlarmChannel =
      AndroidNotificationChannel(
        'epistola_shift_alarms_v2',
        'Будильники смен Epistola',
        description: 'Полноэкранные будильники рабочего календаря',
        importance: Importance.max,
        playSound: true,
        sound: const UriAndroidNotificationSound(_systemAlarmSoundUri),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

  static const String _silentNotificationMode = 'silent';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static PushDeepLinkCoordinator? _deepLinkCoordinator;

  static ShiftAlarmRingHandler? _shiftAlarmRingHandler;

  static final List<ShiftAlarmRingRequest> _pendingShiftAlarmRingRequests =
      <ShiftAlarmRingRequest>[];

  static final Set<String> _knownShiftAlarmRingRequestKeys = <String>{};

  static bool _messagingListenersStarted = false;
  static bool _calendarTimezoneReady = false;

  static Future<void> initialize({
    required PushDeepLinkCoordinator deepLinkCoordinator,
  }) async {
    _deepLinkCoordinator = deepLinkCoordinator;

    await _initializeCalendarTimezone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();

    final launchResponse = launchDetails?.notificationResponse;

    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      _handleLocalNotificationTap(launchResponse);
    }

    final androidPlugin = _androidPlugin;

    await androidPlugin?.createNotificationChannel(_messageChannel);
    await androidPlugin?.createNotificationChannel(_silentMessageChannel);
    await androidPlugin?.createNotificationChannel(_spacesBarChannel);
    await androidPlugin?.createNotificationChannel(_calendarReminderChannel);
    await androidPlugin?.createNotificationChannel(_shiftNotificationChannel);
    await androidPlugin?.createNotificationChannel(_shiftAlarmChannel);
  }

  static void setShiftAlarmRingHandler(ShiftAlarmRingHandler handler) {
    _shiftAlarmRingHandler = handler;
    _flushPendingShiftAlarmRingRequests();
  }

  static void clearShiftAlarmRingHandler() {
    _shiftAlarmRingHandler = null;
  }

  static void _flushPendingShiftAlarmRingRequests() {
    final handler = _shiftAlarmRingHandler;

    if (handler == null || _pendingShiftAlarmRingRequests.isEmpty) {
      return;
    }

    final pending = List<ShiftAlarmRingRequest>.from(
      _pendingShiftAlarmRingRequests,
    );

    _pendingShiftAlarmRingRequests.clear();

    for (final request in pending) {
      unawaited(handler(request));
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin {
    return _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  static Future<void> _initializeCalendarTimezone() async {
    tz_data.initializeTimeZones();

    try {
      final currentTimezone = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(currentTimezone.identifier);

      tz.setLocalLocation(location);
      _calendarTimezoneReady = true;

      if (kDebugMode) {
        debugPrint(
          'Calendar notification timezone: ${currentTimezone.identifier}',
        );
      }
    } catch (error, stackTrace) {
      _calendarTimezoneReady = false;

      if (kDebugMode) {
        debugPrint('Calendar notification timezone setup error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<bool> canScheduleExactCalendarReminders() async {
    final androidPlugin = _androidPlugin;

    if (androidPlugin == null) {
      return false;
    }

    return await androidPlugin.canScheduleExactNotifications() ?? false;
  }

  static Future<bool> requestExactCalendarReminderPermission() async {
    final androidPlugin = _androidPlugin;

    if (androidPlugin == null) {
      return false;
    }

    final alreadyAllowed =
        await androidPlugin.canScheduleExactNotifications() ?? false;

    if (alreadyAllowed) {
      return true;
    }

    return await androidPlugin.requestExactAlarmsPermission() ?? false;
  }

  static Future<bool> requestFullScreenAlarmPermission() async {
    final androidPlugin = _androidPlugin;

    if (androidPlugin == null) {
      return false;
    }

    return await androidPlugin.requestFullScreenIntentPermission() ?? false;
  }

  static Future<bool> scheduleCalendarReminder({
    required int notificationId,
    required DateTime date,
    required int reminderMinutes,
    required String title,
    String? body,
  }) async {
    if (!_calendarTimezoneReady) {
      if (kDebugMode) {
        debugPrint(
          'Calendar reminder was not scheduled: timezone is unavailable',
        );
      }

      return false;
    }

    if (reminderMinutes < 0 || reminderMinutes >= 24 * 60) {
      throw ArgumentError.value(
        reminderMinutes,
        'reminderMinutes',
        'must be between 0 and 1439',
      );
    }

    final canScheduleExact = await canScheduleExactCalendarReminders();

    if (!canScheduleExact) {
      if (kDebugMode) {
        debugPrint(
          'Calendar reminder was not scheduled: '
          'exact alarm permission is unavailable',
        );
      }

      return false;
    }

    final hour = reminderMinutes ~/ 60;
    final minute = reminderMinutes % 60;

    final scheduledDate = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );

    final now = tz.TZDateTime.now(tz.local);

    if (!scheduledDate.isAfter(now)) {
      await cancelCalendarReminder(notificationId: notificationId);

      if (kDebugMode) {
        debugPrint(
          'Calendar reminder was not scheduled because it is in the past: '
          '$scheduledDate',
        );
      }

      return false;
    }

    await _localNotifications.zonedSchedule(
      id: notificationId,
      title: title,
      body: body ?? 'Напоминание календаря',
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _calendarReminderChannel.id,
          _calendarReminderChannel.name,
          channelDescription: _calendarReminderChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );

    if (kDebugMode) {
      debugPrint(
        'Calendar reminder scheduled: '
        'id=$notificationId, at=$scheduledDate',
      );
    }

    return true;
  }

  static Future<void> cancelCalendarReminder({
    required int notificationId,
  }) async {
    await _localNotifications.cancel(id: notificationId);

    if (kDebugMode) {
      debugPrint('Calendar reminder cancelled: id=$notificationId');
    }
  }

  static Future<bool> scheduleShiftAlarmOccurrence({
    required int notificationId,
    required ShiftAlarmOccurrence occurrence,
  }) async {
    if (!_calendarTimezoneReady) {
      if (kDebugMode) {
        debugPrint('Shift alarm was not scheduled: timezone is unavailable');
      }

      return false;
    }

    final canScheduleExact = await canScheduleExactCalendarReminders();

    if (!canScheduleExact) {
      if (kDebugMode) {
        debugPrint(
          'Shift alarm was not scheduled: '
          'exact alarm permission is unavailable',
        );
      }

      return false;
    }

    final alarm = occurrence.alarm;

    final scheduledDate = tz.TZDateTime(
      tz.local,
      occurrence.date.year,
      occurrence.date.month,
      occurrence.date.day,
      alarm.minutesOfDay ~/ 60,
      alarm.minutesOfDay % 60,
    );

    final now = tz.TZDateTime.now(tz.local);

    if (!scheduledDate.isAfter(now)) {
      await cancelShiftAlarmOccurrence(notificationId: notificationId);

      return false;
    }

    final isShortNotification = alarm.type == ShiftAlarmType.notification;

    final durationMilliseconds = isShortNotification
        ? alarm.durationSeconds! * 1000
        : null;

    await _localNotifications.zonedSchedule(
      id: notificationId,
      title: alarm.title,
      body: isShortNotification
          ? 'Оповещение рабочего календаря'
          : 'Будильник рабочего календаря',
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: _shiftAlarmNotificationDetails(
          isShortNotification: isShortNotification,
          durationMilliseconds: durationMilliseconds,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: isShortNotification
          ? null
          : _shiftAlarmPayload(
              title: alarm.title,
              ringAtMilliseconds: scheduledDate.millisecondsSinceEpoch,
            ),
    );

    if (kDebugMode) {
      debugPrint(
        'Shift alarm scheduled: '
        'id=$notificationId, '
        'at=$scheduledDate, '
        'type=${alarm.type.name}, '
        'duration=${alarm.durationSeconds}',
      );
    }

    return true;
  }

  static AndroidNotificationDetails _shiftAlarmNotificationDetails({
    required bool isShortNotification,
    int? durationMilliseconds,
  }) {
    if (isShortNotification) {
      return AndroidNotificationDetails(
        _shiftNotificationChannel.id,
        _shiftNotificationChannel.name,
        channelDescription: _shiftNotificationChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        additionalFlags: Int32List.fromList(<int>[4]),
        timeoutAfter: durationMilliseconds,
        ongoing: false,
        autoCancel: true,
      );
    }

    return AndroidNotificationDetails(
      _shiftAlarmChannel.id,
      _shiftAlarmChannel.name,
      channelDescription: _shiftAlarmChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: const UriAndroidNotificationSound(_systemAlarmSoundUri),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      additionalFlags: Int32List.fromList(<int>[4]),
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: true,
      actions: _shiftAlarmActions,
    );
  }

  static String _shiftAlarmPayload({
    required String title,
    required int ringAtMilliseconds,
  }) {
    return jsonEncode(<String, dynamic>{
      'type': 'shiftAlarm',
      'title': title,
      'ringAtMilliseconds': ringAtMilliseconds,
    });
  }

  static Map<String, dynamic>? _shiftAlarmPayloadData(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      if (decoded['type'] != 'shiftAlarm') {
        return null;
      }

      return decoded;
    } catch (_) {
      return null;
    }
  }

  static String? _shiftAlarmTitleFromPayload(String? payload) {
    final data = _shiftAlarmPayloadData(payload);
    final title = data?['title'];

    if (title is! String || title.trim().isEmpty) {
      return null;
    }

    return title.trim();
  }

  static int? _shiftAlarmRingAtFromPayload(String? payload) {
    final data = _shiftAlarmPayloadData(payload);
    final value = data?['ringAtMilliseconds'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return null;
  }

  static bool _isShiftAlarmAction(String? actionId) {
    return actionId == _shiftAlarmStopActionId ||
        actionId == _shiftAlarmSnoozeActionId;
  }

  static bool _queueShiftAlarmRingRequest(NotificationResponse response) {
    final data = _shiftAlarmPayloadData(response.payload);

    if (data == null) {
      return false;
    }

    final notificationId = response.id;
    final title = _shiftAlarmTitleFromPayload(response.payload);
    final ringAtMilliseconds = _shiftAlarmRingAtFromPayload(response.payload);

    if (notificationId == null || title == null || ringAtMilliseconds == null) {
      return true;
    }

    final request = ShiftAlarmRingRequest(
      notificationId: notificationId,
      title: title,
      ringAtMilliseconds: ringAtMilliseconds,
    );

    if (!_knownShiftAlarmRingRequestKeys.add(request.requestKey)) {
      return true;
    }

    final handler = _shiftAlarmRingHandler;

    if (handler == null) {
      _pendingShiftAlarmRingRequests.add(request);
      return true;
    }

    unawaited(handler(request));

    return true;
  }

  static Future<void> stopShiftAlarm({required int notificationId}) async {
    await _localNotifications.cancel(id: notificationId);

    if (kDebugMode) {
      debugPrint('Shift alarm stopped: id=$notificationId');
    }
  }

  static Future<void> snoozeShiftAlarm({
    required int notificationId,
    required String title,
  }) async {
    await _localNotifications.cancel(id: notificationId);

    await _scheduleSnoozedShiftAlarm(
      plugin: _localNotifications,
      notificationId: notificationId,
      title: title,
    );
  }

  static Future<void> handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) async {
    if (!_isShiftAlarmAction(response.actionId)) {
      return;
    }

    await _handleShiftAlarmAction(response);
  }

  static Future<void> _handleShiftAlarmAction(
    NotificationResponse response,
  ) async {
    final notificationId = response.id;

    if (notificationId == null) {
      if (kDebugMode) {
        debugPrint(
          'Shift alarm action ignored: notification id is unavailable',
        );
      }

      return;
    }

    final plugin = FlutterLocalNotificationsPlugin();

    if (response.actionId == _shiftAlarmStopActionId) {
      await plugin.cancel(id: notificationId);

      if (kDebugMode) {
        debugPrint('Shift alarm stopped: id=$notificationId');
      }

      return;
    }

    if (response.actionId != _shiftAlarmSnoozeActionId) {
      return;
    }

    await plugin.cancel(id: notificationId);

    final title = _shiftAlarmTitleFromPayload(response.payload) ?? 'Будильник';

    await _scheduleSnoozedShiftAlarm(
      plugin: plugin,
      notificationId: notificationId,
      title: title,
    );
  }

  static Future<void> _scheduleSnoozedShiftAlarm({
    required FlutterLocalNotificationsPlugin plugin,
    required int notificationId,
    required String title,
  }) async {
    tz_data.initializeTimeZones();

    final scheduledDate = tz.TZDateTime.now(
      tz.UTC,
    ).add(_shiftAlarmSnoozeDuration);

    await plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: 'Будильник рабочего календаря',
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: _shiftAlarmNotificationDetails(isShortNotification: false),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: _shiftAlarmPayload(
        title: title,
        ringAtMilliseconds: scheduledDate.millisecondsSinceEpoch,
      ),
    );

    if (kDebugMode) {
      debugPrint(
        'Shift alarm snoozed: '
        'id=$notificationId, '
        'until=$scheduledDate',
      );
    }
  }

  static Future<void> cancelShiftAlarmOccurrence({
    required int notificationId,
  }) async {
    await _localNotifications.cancel(id: notificationId);

    if (kDebugMode) {
      debugPrint('Shift alarm cancelled: id=$notificationId');
    }
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
    if (_isShiftAlarmAction(response.actionId)) {
      unawaited(_handleShiftAlarmAction(response));
      return;
    }

    if (_queueShiftAlarmRingRequest(response)) {
      return;
    }

    final payload = response.payload;

    if (payload == null || payload.isEmpty) {
      return;
    }

    final request = PushDeepLinkRequest.fromLocalPayload(payload);

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
