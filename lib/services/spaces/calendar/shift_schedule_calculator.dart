import '../../../domain/models/shift_cycle.dart';

class ShiftScheduleCalculator {
  const ShiftScheduleCalculator();

  static const int cycleLength = 8;

  /// Проверенная опорная дата:
  ///
  /// 14.09.2026
  /// 4 звено -> День 2
  /// 3 звено -> Ночь 1
  /// 1 звено -> последний выходной перед День 1
  ///
  /// Расчёт работает одинаково назад и вперёд от этой даты.
  static final DateTime _anchorDate = DateTime.utc(2026, 9, 14);

  ShiftCyclePhase phaseFor({required DateTime date, required ShiftCrew crew}) {
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);

    final dayOffset = normalizedDate.difference(_anchorDate).inDays;

    final phaseIndex = _positiveModulo(
      crew.anchorPhaseIndex + dayOffset,
      cycleLength,
    );

    return ShiftCyclePhase.values[phaseIndex];
  }

  int phaseIndexFor({required DateTime date, required ShiftCrew crew}) {
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);

    final dayOffset = normalizedDate.difference(_anchorDate).inDays;

    return _positiveModulo(crew.anchorPhaseIndex + dayOffset, cycleLength);
  }

  int _positiveModulo(int value, int modulus) {
    return ((value % modulus) + modulus) % modulus;
  }
}
