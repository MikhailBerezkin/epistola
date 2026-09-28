import 'package:epistola/domain/models/shift_calendar_theme.dart';
import 'package:epistola/services/spaces/calendar/shift_calendar_theme_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('uses light theme by default', () async {
    final preferences = ShiftCalendarThemePreferences();

    final state = await preferences.load();

    expect(state.mode, ShiftCalendarThemeMode.light);
    expect(state.customSlot, ShiftCalendarCustomThemeSlot.first);
    expect(
      state.customFirst.day1,
      ShiftCalendarThemePalette.customFirstDefault.day1,
    );
    expect(
      state.customSecond.day1,
      ShiftCalendarThemePalette.customSecondDefault.day1,
    );
  });

  test('saves and restores selected theme mode', () async {
    final preferences = ShiftCalendarThemePreferences();

    await preferences.saveMode(ShiftCalendarThemeMode.dark);

    final state = await preferences.load();

    expect(state.mode, ShiftCalendarThemeMode.dark);
  });

  test('saves and restores selected custom slot', () async {
    final preferences = ShiftCalendarThemePreferences();

    await preferences.saveCustomSlot(ShiftCalendarCustomThemeSlot.second);

    final state = await preferences.load();

    expect(state.customSlot, ShiftCalendarCustomThemeSlot.second);
  });

  test('saves first custom palette independently', () async {
    final preferences = ShiftCalendarThemePreferences();

    final palette = ShiftCalendarThemePalette.customFirstDefault.copyWith(
      day1: 0xFF112233,
      night2: 0xFF445566,
      background: 0xFF778899,
      vacation: 0xFF123456,
      additionalShift: 0xFF654321,
      selectedDay: 0xFFABCDEF,
      monthHoursBar: 0xFF102030,
      textScale: ShiftCalendarTextScale.large,
    );

    await preferences.saveCustomPalette(
      slot: ShiftCalendarCustomThemeSlot.first,
      palette: palette,
    );

    final state = await preferences.load();

    expect(state.customFirst.day1, 0xFF112233);
    expect(state.customFirst.night2, 0xFF445566);
    expect(state.customFirst.background, 0xFF778899);
    expect(state.customFirst.vacation, 0xFF123456);
    expect(state.customFirst.additionalShift, 0xFF654321);
    expect(state.customFirst.selectedDay, 0xFFABCDEF);
    expect(state.customFirst.monthHoursBar, 0xFF102030);
    expect(state.customFirst.textScale, ShiftCalendarTextScale.large);

    expect(
      state.customSecond.day1,
      ShiftCalendarThemePalette.customSecondDefault.day1,
    );
  });

  test('saves second custom palette independently', () async {
    final preferences = ShiftCalendarThemePreferences();

    final palette = ShiftCalendarThemePalette.customSecondDefault.copyWith(
      offBeforeNight: 0xFF010203,
      recovery: 0xFF040506,
      offAfterRecovery2: 0xFF070809,
      textScale: ShiftCalendarTextScale.compact,
    );

    await preferences.saveCustomPalette(
      slot: ShiftCalendarCustomThemeSlot.second,
      palette: palette,
    );

    final state = await preferences.load();

    expect(state.customSecond.offBeforeNight, 0xFF010203);
    expect(state.customSecond.recovery, 0xFF040506);
    expect(state.customSecond.offAfterRecovery2, 0xFF070809);
    expect(state.customSecond.textScale, ShiftCalendarTextScale.compact);

    expect(
      state.customFirst.recovery,
      ShiftCalendarThemePalette.customFirstDefault.recovery,
    );
  });

  test('reset restores only requested custom palette', () async {
    final preferences = ShiftCalendarThemePreferences();

    await preferences.saveCustomPalette(
      slot: ShiftCalendarCustomThemeSlot.first,
      palette: ShiftCalendarThemePalette.customFirstDefault.copyWith(
        day1: 0xFF111111,
      ),
    );

    await preferences.saveCustomPalette(
      slot: ShiftCalendarCustomThemeSlot.second,
      palette: ShiftCalendarThemePalette.customSecondDefault.copyWith(
        day1: 0xFF222222,
      ),
    );

    await preferences.resetCustomPalette(ShiftCalendarCustomThemeSlot.first);

    final state = await preferences.load();

    expect(
      state.customFirst.day1,
      ShiftCalendarThemePalette.customFirstDefault.day1,
    );
    expect(state.customSecond.day1, 0xFF222222);
  });
}
