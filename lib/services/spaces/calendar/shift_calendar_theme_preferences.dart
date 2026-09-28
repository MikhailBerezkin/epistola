import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/shift_calendar_theme.dart';

class ShiftCalendarThemePreferences {
  static const String _modeKey = 'calendar.ui.theme.mode.v2';
  static const String _customSlotKey = 'calendar.ui.theme.custom_slot.v2';

  Future<ShiftCalendarThemeState> load() async {
    final preferences = await SharedPreferences.getInstance();

    return ShiftCalendarThemeState(
      mode: ShiftCalendarThemeMode.fromStorageValue(
        preferences.getString(_modeKey),
      ),
      customSlot: ShiftCalendarCustomThemeSlot.fromStorageValue(
        preferences.getString(_customSlotKey),
      ),
      customFirst: _readPalette(
        preferences,
        prefix: 'calendar.ui.theme.custom1.v2',
        fallback: ShiftCalendarThemePalette.customFirstDefault,
      ),
      customSecond: _readPalette(
        preferences,
        prefix: 'calendar.ui.theme.custom2.v2',
        fallback: ShiftCalendarThemePalette.customSecondDefault,
      ),
    );
  }

  Future<void> saveState(ShiftCalendarThemeState state) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_modeKey, state.mode.storageValue);

    await preferences.setString(_customSlotKey, state.customSlot.storageValue);

    await _writePalette(
      preferences,
      prefix: 'calendar.ui.theme.custom1.v2',
      palette: state.customFirst,
    );

    await _writePalette(
      preferences,
      prefix: 'calendar.ui.theme.custom2.v2',
      palette: state.customSecond,
    );
  }

  Future<void> saveMode(ShiftCalendarThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_modeKey, mode.storageValue);
  }

  Future<void> saveCustomSlot(ShiftCalendarCustomThemeSlot slot) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_customSlotKey, slot.storageValue);
  }

  Future<void> saveCustomPalette({
    required ShiftCalendarCustomThemeSlot slot,
    required ShiftCalendarThemePalette palette,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    final prefix = switch (slot) {
      ShiftCalendarCustomThemeSlot.first => 'calendar.ui.theme.custom1.v2',
      ShiftCalendarCustomThemeSlot.second => 'calendar.ui.theme.custom2.v2',
    };

    await _writePalette(preferences, prefix: prefix, palette: palette);
  }

  Future<void> resetCustomPalette(ShiftCalendarCustomThemeSlot slot) async {
    final fallback = switch (slot) {
      ShiftCalendarCustomThemeSlot.first =>
        ShiftCalendarThemePalette.customFirstDefault,
      ShiftCalendarCustomThemeSlot.second =>
        ShiftCalendarThemePalette.customSecondDefault,
    };

    await saveCustomPalette(slot: slot, palette: fallback);
  }

  ShiftCalendarThemePalette _readPalette(
    SharedPreferences preferences, {
    required String prefix,
    required ShiftCalendarThemePalette fallback,
  }) {
    return ShiftCalendarThemePalette(
      day1: preferences.getInt('$prefix.day1') ?? fallback.day1,
      day2: preferences.getInt('$prefix.day2') ?? fallback.day2,
      offBeforeNight:
          preferences.getInt('$prefix.off_before_night') ??
          fallback.offBeforeNight,
      night1: preferences.getInt('$prefix.night1') ?? fallback.night1,
      night2: preferences.getInt('$prefix.night2') ?? fallback.night2,
      recovery: preferences.getInt('$prefix.recovery') ?? fallback.recovery,
      offAfterRecovery1:
          preferences.getInt('$prefix.off_after_recovery1') ??
          fallback.offAfterRecovery1,
      offAfterRecovery2:
          preferences.getInt('$prefix.off_after_recovery2') ??
          fallback.offAfterRecovery2,
      background:
          preferences.getInt('$prefix.background') ?? fallback.background,
      vacation: preferences.getInt('$prefix.vacation') ?? fallback.vacation,
      additionalShift:
          preferences.getInt('$prefix.additional_shift') ??
          fallback.additionalShift,
      selectedDay:
          preferences.getInt('$prefix.selected_day') ?? fallback.selectedDay,
      monthHoursBar:
          preferences.getInt('$prefix.month_hours_bar') ??
          fallback.monthHoursBar,
      textScale: ShiftCalendarTextScale.fromStorageValue(
        preferences.getString('$prefix.text_scale'),
      ),
    );
  }

  Future<void> _writePalette(
    SharedPreferences preferences, {
    required String prefix,
    required ShiftCalendarThemePalette palette,
  }) async {
    await preferences.setInt('$prefix.day1', palette.day1);
    await preferences.setInt('$prefix.day2', palette.day2);
    await preferences.setInt(
      '$prefix.off_before_night',
      palette.offBeforeNight,
    );
    await preferences.setInt('$prefix.night1', palette.night1);
    await preferences.setInt('$prefix.night2', palette.night2);
    await preferences.setInt('$prefix.recovery', palette.recovery);
    await preferences.setInt(
      '$prefix.off_after_recovery1',
      palette.offAfterRecovery1,
    );
    await preferences.setInt(
      '$prefix.off_after_recovery2',
      palette.offAfterRecovery2,
    );
    await preferences.setInt('$prefix.background', palette.background);
    await preferences.setInt('$prefix.vacation', palette.vacation);
    await preferences.setInt(
      '$prefix.additional_shift',
      palette.additionalShift,
    );
    await preferences.setInt('$prefix.selected_day', palette.selectedDay);
    await preferences.setInt('$prefix.month_hours_bar', palette.monthHoursBar);
    await preferences.setString(
      '$prefix.text_scale',
      palette.textScale.storageValue,
    );
  }
}
