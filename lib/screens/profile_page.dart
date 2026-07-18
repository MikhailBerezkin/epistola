import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/profile_header.dart';
import '../widgets/profile_info_card.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/avatar/firebase_avatar_service.dart';
import '../domain/models/avatar_upload_request.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void openEditProfile({
    required BuildContext context,
    required String uid,
    required String name,
    required String phone,
    required String about,
    required EditProfileField initialField,
    required String contactEmail,
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
          contactEmail: contactEmail,
        ),
      ),
    );
  }

  Future<void> pickAndUploadAvatar({
    required BuildContext context,
    required String userId,
  }) async {
    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();

    final request = AvatarUploadRequest(
      bytes: bytes,
      fileName: pickedFile.name,
      mimeType: pickedFile.mimeType ?? 'image/jpeg',
    );

    await FirebaseAvatarService().uploadAvatar(
      userId: userId,
      request: request,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Аватар обновлён')));
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
        final contactEmail = data?['contactEmail'] ?? '';
        final avatarUrl = data?['avatarUrl'] ?? '';

        final hasPhone = phone.toString().isNotEmpty;
        final hasEmail = contactEmail.toString().isNotEmpty;

        final contactTitle = hasPhone && hasEmail
            ? 'Телефон / e-mail'
            : hasPhone
            ? 'Телефон'
            : hasEmail
            ? 'E-mail'
            : 'Контакты';

        final contactSubtitle = hasPhone && hasEmail
            ? '$phone\n$contactEmail'
            : hasPhone
            ? phone.toString()
            : hasEmail
            ? contactEmail.toString()
            : 'Не указаны';

        return Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              ProfileHeader(
                name: userName,
                email: '',
                avatarUrl: avatarUrl,
                onAvatarTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ListTile(
                              title: Text(
                                'Аватар',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library_outlined),
                              title: const Text('Выбрать из галереи'),
                              onTap: () {
                                Navigator.pop(context);
                                pickAndUploadAvatar(
                                  context: context,
                                  userId: user.uid,
                                );
                              },
                            ),
                            if (avatarUrl.toString().isNotEmpty)
                              ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: const Text('Удалить аватар'),
                                onTap: () {
                                  Navigator.pop(context);
                                  // TODO: Delete avatar
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
                onNameTap: () {
                  openEditProfile(
                    context: context,
                    uid: user.uid,
                    name: userName,
                    phone: phone,
                    about: about,
                    initialField: EditProfileField.name,
                    contactEmail: contactEmail,
                  );
                },
              ),
              const SizedBox(height: 24),

              ProfileInfoCard(
                icon: Icons.contact_phone,
                title: contactTitle,
                subtitle: contactSubtitle,
                showChevron: true,
                onTap: () async {
                  final selectedField =
                      await showModalBottomSheet<EditProfileField>(
                        context: context,
                        showDragHandle: true,
                        builder: (context) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const ListTile(
                                  title: Text(
                                    'Контактная информация',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.phone),
                                  title: const Text('Телефон'),
                                  onTap: () => Navigator.pop(
                                    context,
                                    EditProfileField.phone,
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.email_outlined),
                                  title: const Text('E-mail'),
                                  onTap: () => Navigator.pop(
                                    context,
                                    EditProfileField.contactEmail,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );

                  if (selectedField == null || !context.mounted) return;

                  openEditProfile(
                    context: context,
                    uid: user.uid,
                    name: userName,
                    phone: phone,
                    contactEmail: contactEmail,
                    about: about,
                    initialField: selectedField,
                  );
                },
              ),
              const SizedBox(height: 12),
              ProfileInfoCard(
                icon: Icons.info_outline,
                title: 'О себе',
                subtitle: about.toString().isNotEmpty ? about : 'Пока пусто',
                showChevron: true,
                onTap: () {
                  openEditProfile(
                    context: context,
                    uid: user.uid,
                    name: userName,
                    phone: phone,
                    about: about,
                    initialField: EditProfileField.about,
                    contactEmail: contactEmail,
                  );
                },
              ),
              const SizedBox(height: 12),

              ProfileInfoCard(
                icon: Icons.settings,
                title: 'Настройки',
                subtitle: 'Тема, уведомления, выход',
                showChevron: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
