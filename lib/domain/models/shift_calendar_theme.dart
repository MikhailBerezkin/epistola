enum ShiftCalendarThemeMode {
  light('light'),
  dark('dark'),
  custom('custom');

  const ShiftCalendarThemeMode(this.storageValue);

  final String storageValue;

  static ShiftCalendarThemeMode fromStorageValue(Object? value) {
    return switch (value) {
      'dark' => ShiftCalendarThemeMode.dark,
      'custom' => ShiftCalendarThemeMode.custom,
      _ => ShiftCalendarThemeMode.light,
    };
  }
}

enum ShiftCalendarCustomThemeSlot {
  first('first'),
  second('second');

  const ShiftCalendarCustomThemeSlot(this.storageValue);

  final String storageValue;

  static ShiftCalendarCustomThemeSlot fromStorageValue(Object? value) {
    return switch (value) {
      'second' => ShiftCalendarCustomThemeSlot.second,
      _ => ShiftCalendarCustomThemeSlot.first,
    };
  }

  String get displayName {
    return switch (this) {
      ShiftCalendarCustomThemeSlot.first => 'Своя 1',
      ShiftCalendarCustomThemeSlot.second => 'Своя 2',
    };
  }
}

enum ShiftCalendarTextScale {
  compact('compact', 0.90, 'Компактный'),
  normal('normal', 1.00, 'Обычный'),
  large('large', 1.15, 'Крупный');

  const ShiftCalendarTextScale(
    this.storageValue,
    this.factor,
    this.displayName,
  );

  final String storageValue;
  final double factor;
  final String displayName;

  static ShiftCalendarTextScale fromStorageValue(Object? value) {
    return switch (value) {
      'compact' => ShiftCalendarTextScale.compact,
      'large' => ShiftCalendarTextScale.large,
      _ => ShiftCalendarTextScale.normal,
    };
  }
}

class ShiftCalendarThemePalette {
  const ShiftCalendarThemePalette({
    required this.day1,
    required this.day2,
    required this.offBeforeNight,
    required this.night1,
    required this.night2,
    required this.recovery,
    required this.offAfterRecovery1,
    required this.offAfterRecovery2,
    required this.background,
    required this.vacation,
    required this.additionalShift,
    required this.selectedDay,
    required this.monthHoursBar,
    required this.textScale,
  });

  final int day1;
  final int day2;
  final int offBeforeNight;
  final int night1;
  final int night2;
  final int recovery;
  final int offAfterRecovery1;
  final int offAfterRecovery2;

  final int background;
  final int vacation;
  final int additionalShift;
  final int selectedDay;
  final int monthHoursBar;

  final ShiftCalendarTextScale textScale;

  static const light = ShiftCalendarThemePalette(
    day1: 0xFFDCEBE4,
    day2: 0xFFDCEBE4,
    offBeforeNight: 0xFFF3F4F3,
    night1: 0xFFD5E4E6,
    night2: 0xFFD5E4E6,
    recovery: 0xFFE3E2E8,
    offAfterRecovery1: 0xFFF3F4F3,
    offAfterRecovery2: 0xFFF3F4F3,
    background: 0xFFFFFFFF,
    vacation: 0xFF4F6FA8,
    additionalShift: 0xFF7C4DFF,
    selectedDay: 0xFFC40827,
    monthHoursBar: 0xFFE7E9E8,
    textScale: ShiftCalendarTextScale.normal,
  );

  static const dark = ShiftCalendarThemePalette(
    day1: 0xFF394943,
    day2: 0xFF394943,
    offBeforeNight: 0xFF202327,
    night1: 0xFF263E42,
    night2: 0xFF263E42,
    recovery: 0xFF383A43,
    offAfterRecovery1: 0xFF202327,
    offAfterRecovery2: 0xFF202327,
    background: 0xFF121416,
    vacation: 0xFF8FA7D6,
    additionalShift: 0xFFB388FF,
    selectedDay: 0xFFFF7088,
    monthHoursBar: 0xFF2D3135,
    textScale: ShiftCalendarTextScale.normal,
  );

  static const customFirstDefault = ShiftCalendarThemePalette(
    day1: 0xFFDCEBE4,
    day2: 0xFFD5E8DF,
    offBeforeNight: 0xFFF1F3F2,
    night1: 0xFFD5E4E6,
    night2: 0xFFCADDE1,
    recovery: 0xFFE3E2E8,
    offAfterRecovery1: 0xFFF3F4F3,
    offAfterRecovery2: 0xFFEAEEEC,
    background: 0xFFFFFFFF,
    vacation: 0xFF4F6FA8,
    additionalShift: 0xFF7C4DFF,
    selectedDay: 0xFFC40827,
    monthHoursBar: 0xFFE7E9E8,
    textScale: ShiftCalendarTextScale.normal,
  );

  static const customSecondDefault = ShiftCalendarThemePalette(
    day1: 0xFF394943,
    day2: 0xFF314640,
    offBeforeNight: 0xFF202327,
    night1: 0xFF263E42,
    night2: 0xFF22373C,
    recovery: 0xFF383A43,
    offAfterRecovery1: 0xFF202327,
    offAfterRecovery2: 0xFF25292D,
    background: 0xFF121416,
    vacation: 0xFF8FA7D6,
    additionalShift: 0xFFB388FF,
    selectedDay: 0xFFFF7088,
    monthHoursBar: 0xFF2D3135,
    textScale: ShiftCalendarTextScale.normal,
  );

  ShiftCalendarThemePalette copyWith({
    int? day1,
    int? day2,
    int? offBeforeNight,
    int? night1,
    int? night2,
    int? recovery,
    int? offAfterRecovery1,
    int? offAfterRecovery2,
    int? background,
    int? vacation,
    int? additionalShift,
    int? selectedDay,
    int? monthHoursBar,
    ShiftCalendarTextScale? textScale,
  }) {
    return ShiftCalendarThemePalette(
      day1: day1 ?? this.day1,
      day2: day2 ?? this.day2,
      offBeforeNight: offBeforeNight ?? this.offBeforeNight,
      night1: night1 ?? this.night1,
      night2: night2 ?? this.night2,
      recovery: recovery ?? this.recovery,
      offAfterRecovery1: offAfterRecovery1 ?? this.offAfterRecovery1,
      offAfterRecovery2: offAfterRecovery2 ?? this.offAfterRecovery2,
      background: background ?? this.background,
      vacation: vacation ?? this.vacation,
      additionalShift: additionalShift ?? this.additionalShift,
      selectedDay: selectedDay ?? this.selectedDay,
      monthHoursBar: monthHoursBar ?? this.monthHoursBar,
      textScale: textScale ?? this.textScale,
    );
  }
}

class ShiftCalendarThemeState {
  const ShiftCalendarThemeState({
    required this.mode,
    required this.customSlot,
    required this.customFirst,
    required this.customSecond,
  });

  final ShiftCalendarThemeMode mode;
  final ShiftCalendarCustomThemeSlot customSlot;
  final ShiftCalendarThemePalette customFirst;
  final ShiftCalendarThemePalette customSecond;

  ShiftCalendarThemePalette get activePalette {
    return switch (mode) {
      ShiftCalendarThemeMode.light => ShiftCalendarThemePalette.light,
      ShiftCalendarThemeMode.dark => ShiftCalendarThemePalette.dark,
      ShiftCalendarThemeMode.custom =>
        customSlot == ShiftCalendarCustomThemeSlot.first
            ? customFirst
            : customSecond,
    };
  }

  ShiftCalendarThemeState copyWith({
    ShiftCalendarThemeMode? mode,
    ShiftCalendarCustomThemeSlot? customSlot,
    ShiftCalendarThemePalette? customFirst,
    ShiftCalendarThemePalette? customSecond,
  }) {
    return ShiftCalendarThemeState(
      mode: mode ?? this.mode,
      customSlot: customSlot ?? this.customSlot,
      customFirst: customFirst ?? this.customFirst,
      customSecond: customSecond ?? this.customSecond,
    );
  }
}
