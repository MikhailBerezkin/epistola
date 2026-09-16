enum ShiftCyclePhase {
  day1('День 1'),
  day2('День 2'),
  offBeforeNight('Вых'),
  night1('Ночь 1'),
  night2('Ночь 2'),
  recovery('О'),
  offAfterRecovery1('Вых'),
  offAfterRecovery2('Вых');

  const ShiftCyclePhase(this.displayLabel);

  final String displayLabel;

  bool get isDayShift {
    return this == ShiftCyclePhase.day1 || this == ShiftCyclePhase.day2;
  }

  bool get isNightShift {
    return this == ShiftCyclePhase.night1 || this == ShiftCyclePhase.night2;
  }

  bool get isRecovery => this == ShiftCyclePhase.recovery;

  bool get isOff {
    return this == ShiftCyclePhase.offBeforeNight ||
        this == ShiftCyclePhase.offAfterRecovery1 ||
        this == ShiftCyclePhase.offAfterRecovery2;
  }
}

enum ShiftCrew {
  crew1(number: 1, anchorPhaseIndex: 7),
  crew2(number: 2, anchorPhaseIndex: 5),
  crew3(number: 3, anchorPhaseIndex: 3),
  crew4(number: 4, anchorPhaseIndex: 1);

  const ShiftCrew({required this.number, required this.anchorPhaseIndex});

  final int number;

  /// Положение звена в 8-дневном цикле на опорную дату 14.09.2026.
  final int anchorPhaseIndex;

  String get displayName => '$number звено';
}
