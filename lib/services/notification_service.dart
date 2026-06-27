import 'package:vibration/vibration.dart';

class NotificationService {
  static Future<void> vibrate() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 80);
    }
  }
}
