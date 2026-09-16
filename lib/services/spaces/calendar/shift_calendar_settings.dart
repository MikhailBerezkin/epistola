import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/shift_cycle.dart';

class ShiftCalendarSettings {
  const ShiftCalendarSettings();

  static const _crewNumberKey = 'shift_calendar_crew_number';

  Future<ShiftCrew> loadCrew() async {
    final prefs = await SharedPreferences.getInstance();
    final crewNumber = prefs.getInt(_crewNumberKey);

    return switch (crewNumber) {
      1 => ShiftCrew.crew1,
      2 => ShiftCrew.crew2,
      3 => ShiftCrew.crew3,
      4 => ShiftCrew.crew4,
      _ => ShiftCrew.crew4,
    };
  }

  Future<void> saveCrew(ShiftCrew crew) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_crewNumberKey, crew.number);
  }
}
