import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final class ShiftAlarmNativeBridge {
  const ShiftAlarmNativeBridge._();

  static const MethodChannel _channel = MethodChannel('epistola/shift_alarm');

  static bool get isSupported {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<bool> schedule({
    required int notificationId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    if (!isSupported) {
      return false;
    }

    final result = await _channel
        .invokeMethod<bool>('schedule', <String, Object?>{
          'notificationId': notificationId,
          'title': title,
          'triggerAtMilliseconds': scheduledAt.millisecondsSinceEpoch,
        });

    return result ?? false;
  }

  static Future<void> cancel({required int notificationId}) async {
    if (!isSupported) {
      return;
    }

    await _channel.invokeMethod<void>('cancel', <String, Object?>{
      'notificationId': notificationId,
    });
  }
}
