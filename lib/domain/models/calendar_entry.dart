enum CalendarEntryKind { task, note }

enum CalendarEntryPriority { none, low, medium, high }

final class CalendarEntry {
  CalendarEntry({
    required this.id,
    required this.kind,
    required DateTime date,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.scheduledMinutes,
    this.reminderMinutes,
    this.priority = CalendarEntryPriority.none,
    this.colorValue,
    this.isCompleted = false,
    this.completedAt,
  }) : date = _dateOnly(date);

  final String id;
  final CalendarEntryKind kind;

  /// День, к которому относится запись.
  ///
  /// Время здесь всегда отбрасывается.
  final DateTime date;

  final String title;

  /// Дополнительный текст записи.
  final String? description;

  /// Время самого дела:
  /// количество минут от начала суток.
  ///
  /// Например:
  /// 09:30 -> 570.
  ///
  /// null = время не задано.
  final int? scheduledMinutes;

  /// Время локального уведомления:
  /// количество минут от начала суток.
  ///
  /// null = будильник выключен.
  final int? reminderMinutes;

  final CalendarEntryPriority priority;

  /// ARGB-значение пользовательского цвета.
  ///
  /// null = используется стандартный цвет.
  ///
  /// Модель не зависит от Flutter Color.
  final int? colorValue;

  /// Выполнение относится прежде всего к CalendarEntryKind.task.
  final bool isCompleted;

  final DateTime? completedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasScheduledTime => scheduledMinutes != null;

  bool get hasReminder => reminderMinutes != null;

  int get dayKey {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  bool get isValid {
    if (id.trim().isEmpty || title.trim().isEmpty) {
      return false;
    }

    if (!_isValidMinutes(scheduledMinutes) ||
        !_isValidMinutes(reminderMinutes)) {
      return false;
    }

    if (kind == CalendarEntryKind.note &&
        (isCompleted || completedAt != null)) {
      return false;
    }

    if (isCompleted && completedAt == null) {
      return false;
    }

    if (!isCompleted && completedAt != null) {
      return false;
    }

    return true;
  }

  bool occursOn(DateTime other) {
    return date.year == other.year &&
        date.month == other.month &&
        date.day == other.day;
  }

  static bool _isValidMinutes(int? value) {
    if (value == null) {
      return true;
    }

    return value >= 0 && value < 24 * 60;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
