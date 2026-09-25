import 'shift_cycle.dart';

enum ShiftAlarmScope {
  work,
  always,
  vacation;

  String get displayTitle {
    return switch (this) {
      ShiftAlarmScope.work => 'Рабочие смены',
      ShiftAlarmScope.always => 'Всегда',
      ShiftAlarmScope.vacation => 'В отпуске',
    };
  }
}

enum ShiftAlarmType {
  alarm,
  notification;

  String get displayTitle {
    return switch (this) {
      ShiftAlarmType.alarm => 'Будильник',
      ShiftAlarmType.notification => 'Оповещение',
    };
  }
}

extension ShiftAlarmPhasePresentation on ShiftCyclePhase {
  String get alarmEditorTitle {
    return switch (this) {
      ShiftCyclePhase.day1 => 'День 1',
      ShiftCyclePhase.day2 => 'День 2',
      ShiftCyclePhase.offBeforeNight => 'Выходной',
      ShiftCyclePhase.night1 => 'Ночь 1',
      ShiftCyclePhase.night2 => 'Ночь 2',
      ShiftCyclePhase.recovery => 'Отсыпной',
      ShiftCyclePhase.offAfterRecovery1 => 'Выходной 1',
      ShiftCyclePhase.offAfterRecovery2 => 'Выходной 2',
    };
  }
}

final class ShiftAlarm {
  ShiftAlarm({
    required this.id,
    required this.phase,
    required this.scope,
    required this.type,
    required this.title,
    required this.minutesOfDay,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.durationSeconds,
  });

  static const List<int> allowedNotificationDurations = <int>[
    5,
    10,
    15,
    20,
    30,
    60,
  ];

  final String id;

  /// Фаза 8-дневного рабочего цикла, к которой относится шаблон сигнала.
  final ShiftCyclePhase phase;

  /// Область действия сигнала.
  ///
  /// work:
  /// обычный сигнал плитки, подавляется во время отпуска.
  ///
  /// always:
  /// работает независимо от отпуска.
  ///
  /// vacation:
  /// работает только во время отпуска.
  final ShiftAlarmScope scope;

  /// alarm:
  /// настоящий будильник, требующий ручного отключения.
  ///
  /// notification:
  /// короткий сигнал, автоматически прекращающийся
  /// после durationSeconds.
  final ShiftAlarmType type;

  /// Пользовательское название.
  ///
  /// Например:
  /// "Подъём",
  /// "Конец обеда №1",
  /// "Собираться домой".
  final String title;

  /// Время срабатывания как количество минут от начала суток.
  ///
  /// 05:40 -> 340
  /// 13:10 -> 790
  final int minutesOfDay;

  /// Используется только для ShiftAlarmType.notification.
  ///
  /// Допустимые значения:
  /// 5 / 10 / 15 / 20 / 30 / 60 секунд.
  ///
  /// Для ShiftAlarmType.alarm должно быть null.
  final int? durationSeconds;

  /// Позволяет временно выключить конкретный шаблон
  /// без его удаления.
  final bool enabled;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAlarm => type == ShiftAlarmType.alarm;

  bool get isNotification => type == ShiftAlarmType.notification;

  bool get isValid {
    if (id.trim().isEmpty || title.trim().isEmpty) {
      return false;
    }

    if (minutesOfDay < 0 || minutesOfDay >= 24 * 60) {
      return false;
    }

    if (updatedAt.isBefore(createdAt)) {
      return false;
    }

    switch (type) {
      case ShiftAlarmType.alarm:
        if (durationSeconds != null) {
          return false;
        }

      case ShiftAlarmType.notification:
        final duration = durationSeconds;

        if (duration == null ||
            !allowedNotificationDurations.contains(duration)) {
          return false;
        }
    }

    return true;
  }

  ShiftAlarm copyWith({
    String? id,
    ShiftCyclePhase? phase,
    ShiftAlarmScope? scope,
    ShiftAlarmType? type,
    String? title,
    int? minutesOfDay,
    Object? durationSeconds = _unset,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShiftAlarm(
      id: id ?? this.id,
      phase: phase ?? this.phase,
      scope: scope ?? this.scope,
      type: type ?? this.type,
      title: title ?? this.title,
      minutesOfDay: minutesOfDay ?? this.minutesOfDay,
      durationSeconds: identical(durationSeconds, _unset)
          ? this.durationSeconds
          : durationSeconds as int?,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _unset = Object();
}
