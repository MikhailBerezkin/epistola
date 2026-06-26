import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/app_settings.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> logout(BuildContext context) async {
    HapticFeedback.mediumImpact();

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выйти из аккаунта?'),
          content: const Text('Для входа снова потребуется авторизация.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
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
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Уведомления'),
              subtitle: const Text('Добавим позже'),
              enabled: false,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('О приложении'),
              subtitle: const Text('Epistola'),
              enabled: false,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Выйти', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Выйти из текущего аккаунта'),
              onTap: () => logout(context),
            ),
          ),
        ],
      ),
    );
  }
}
