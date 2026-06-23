import 'package:cloud_firestore/cloud_firestore.dart';

class StatusHelper {
  static String title(String status) {
    switch (status) {
      case 'muted':
        return 'Мьют';
      case 'banned':
        return 'Бан';
      default:
        return 'Нормальный';
    }
  }

  static bool isActive(Map<String, dynamic> statusData) {
    final permanent = statusData['permanent'] == true;
    final expiresAt = statusData['expiresAt'];

    if (permanent) return true;

    if (expiresAt is Timestamp) {
      return expiresAt.toDate().isAfter(DateTime.now());
    }

    return false;
  }

  static String formatDetails(Map<String, dynamic> statusData) {
    final reason = statusData['reason'];
    final expiresAt = statusData['expiresAt'];
    final permanent = statusData['permanent'] == true;

    final parts = <String>[];

    if (reason != null && reason.toString().isNotEmpty) {
      parts.add('Причина: $reason');
    }

    if (permanent) {
      parts.add('Срок: навсегда');
    } else if (expiresAt is Timestamp) {
      final dateTime = expiresAt.toDate();
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      parts.add('До: $day.$month.$year $hour:$minute');
    }

    return parts.join('\n');
  }
}
