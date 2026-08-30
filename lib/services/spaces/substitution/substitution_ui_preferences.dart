import 'package:shared_preferences/shared_preferences.dart';

class SubstitutionUiPreferencesState {
  const SubstitutionUiPreferencesState({
    required this.useNumberOnly,
    required this.showStatistics,
  });

  final bool useNumberOnly;
  final bool showStatistics;
}

class SubstitutionUiPreferences {
  static const String _numberOnlyKey = 'substitution.ui.queue_number_only.v1';

  static const String _showStatisticsKey = 'substitution.ui.show_statistics.v1';

  Future<SubstitutionUiPreferencesState> load() async {
    final preferences = await SharedPreferences.getInstance();

    return SubstitutionUiPreferencesState(
      useNumberOnly: preferences.getBool(_numberOnlyKey) ?? true,
      showStatistics: preferences.getBool(_showStatisticsKey) ?? false,
    );
  }

  Future<void> saveUseNumberOnly(bool value) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(_numberOnlyKey, value);
  }

  Future<void> saveShowStatistics(bool value) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(_showStatisticsKey, value);
  }
}
