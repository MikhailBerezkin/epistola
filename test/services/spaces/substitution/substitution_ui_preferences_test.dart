import 'package:epistola/services/spaces/substitution/substitution_ui_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('uses number-only queue and hidden statistics by default', () async {
    final preferences = SubstitutionUiPreferences();

    final state = await preferences.load();

    expect(state.useNumberOnly, isTrue);
    expect(state.showStatistics, isFalse);
  });

  test('saves and restores queue display preference', () async {
    final preferences = SubstitutionUiPreferences();

    await preferences.saveUseNumberOnly(false);

    final state = await preferences.load();

    expect(state.useNumberOnly, isFalse);
    expect(state.showStatistics, isFalse);
  });

  test('saves and restores statistics visibility preference', () async {
    final preferences = SubstitutionUiPreferences();

    await preferences.saveShowStatistics(true);

    final state = await preferences.load();

    expect(state.useNumberOnly, isTrue);
    expect(state.showStatistics, isTrue);
  });

  test('keeps both preferences independently', () async {
    final preferences = SubstitutionUiPreferences();

    await preferences.saveUseNumberOnly(false);
    await preferences.saveShowStatistics(true);

    final state = await preferences.load();

    expect(state.useNumberOnly, isFalse);
    expect(state.showStatistics, isTrue);
  });
}
