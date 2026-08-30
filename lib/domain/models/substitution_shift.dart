enum SubstitutionShiftKind { day, night }

final class SubstitutionShift {
  SubstitutionShift({
    required this.year,
    required this.month,
    required this.day,
    required this.kind,
  }) {
    _validateDate(year: year, month: month, day: day);
  }

  final int year;
  final int month;
  final int day;
  final SubstitutionShiftKind kind;

  /// Месяц статистики всегда определяется датой начала смены.
  int get statisticsYear => year;

  int get statisticsMonth => month;

  int get startHour {
    return switch (kind) {
      SubstitutionShiftKind.day => 8,
      SubstitutionShiftKind.night => 20,
    };
  }

  int get endHour {
    return switch (kind) {
      SubstitutionShiftKind.day => 20,
      SubstitutionShiftKind.night => 8,
    };
  }

  /// Ночная смена заканчивается уже на следующий календарный день,
  /// но целиком относится к дате её начала.
  bool get endsOnNextCalendarDay {
    return kind == SubstitutionShiftKind.night;
  }

  DateTime get calendarDateUtc {
    return DateTime.utc(year, month, day);
  }

  static void _validateDate({
    required int year,
    required int month,
    required int day,
  }) {
    if (year < 1) {
      throw ArgumentError.value(
        year,
        'year',
        'year must be greater than zero.',
      );
    }

    if (month < 1 || month > 12) {
      throw ArgumentError.value(
        month,
        'month',
        'month must be between 1 and 12.',
      );
    }

    if (day < 1 || day > 31) {
      throw ArgumentError.value(day, 'day', 'day is outside valid range.');
    }

    final resolvedDate = DateTime.utc(year, month, day);

    if (resolvedDate.year != year ||
        resolvedDate.month != month ||
        resolvedDate.day != day) {
      throw ArgumentError(
        'Invalid calendar date: '
        '$year-$month-$day.',
      );
    }
  }
}
