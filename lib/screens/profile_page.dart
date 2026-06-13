import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/app_settings.dart';
import 'edit_profile_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void openEditProfile({
    required BuildContext context,
    required String uid,
    required String name,
    required String phone,
    required String about,
    required EditProfileField initialField,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          uid: uid,
          name: name,
          phone: phone,
          about: about,
          initialField: initialField,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Пользователь не найден'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;

        final userName = data?['name'] ?? 'Пользователь';
        final phone = data?['phone'] ?? '';
        final about = data?['about'] ?? '';

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 48,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  openEditProfile(
                    context: context,
                    uid: user.uid,
                    name: userName,
                    phone: phone,
                    about: about,
                    initialField: EditProfileField.name,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.email ?? '',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.badge),
                  title: const Text('UID'),
                  subtitle: Text(user.uid),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Телефон'),
                  subtitle: Text(
                    phone.toString().isNotEmpty ? phone : 'Не указан',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    openEditProfile(
                      context: context,
                      uid: user.uid,
                      name: userName,
                      phone: phone,
                      about: about,
                      initialField: EditProfileField.phone,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('О себе'),
                  subtitle: Text(
                    about.toString().isNotEmpty ? about : 'Пока пусто',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    openEditProfile(
                      context: context,
                      uid: user.uid,
                      name: userName,
                      phone: phone,
                      about: about,
                      initialField: EditProfileField.about,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
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
            ],
          ),
        );
      },
    );
  }
}
