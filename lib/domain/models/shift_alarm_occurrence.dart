import 'shift_alarm.dart';

final class ShiftAlarmOccurrence {
  const ShiftAlarmOccurrence({required this.alarm, required this.date});

  final ShiftAlarm alarm;

  /// Конкретный календарный день срабатывания.
  final DateTime date;

  DateTime get scheduledAt {
    return DateTime(
      date.year,
      date.month,
      date.day,
      alarm.minutesOfDay ~/ 60,
      alarm.minutesOfDay % 60,
    );
  }

  String get occurrenceId {
    final normalizedDate =
        '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';

    return '${alarm.id}_$normalizedDate';
  }
}
