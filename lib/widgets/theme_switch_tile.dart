import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/app_settings.dart';

class ThemeSwitchTile extends StatelessWidget {
  const ThemeSwitchTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.dark_mode),
        title: const Text('Тёмная тема'),
        trailing: ValueListenableBuilder<ThemeMode>(
          valueListenable: AppSettings.themeModeNotifier,
          builder: (context, mode, _) {
            return Switch(
              value: mode == ThemeMode.dark,
              onChanged: (value) {
                HapticFeedback.selectionClick();

                AppSettings.setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
