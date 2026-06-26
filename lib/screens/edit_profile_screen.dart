import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum EditProfileField { name, phone, contactEmail, about }

class EditProfileScreen extends StatefulWidget {
  final String uid;
  final String name;
  final String phone;
  final String contactEmail;
  final String about;
  final EditProfileField initialField;

  const EditProfileScreen({
    super.key,
    required this.uid,
    required this.name,
    required this.phone,
    required this.contactEmail,
    required this.about,
    this.initialField = EditProfileField.name,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController contactEmailController;
  late final TextEditingController aboutController;

  final nameFocusNode = FocusNode();
  final phoneFocusNode = FocusNode();
  final contactEmailFocusNode = FocusNode();
  final aboutFocusNode = FocusNode();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.name);
    phoneController = TextEditingController(text: widget.phone);
    contactEmailController = TextEditingController(text: widget.contactEmail);
    aboutController = TextEditingController(text: widget.about);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (widget.initialField) {
        case EditProfileField.name:
          nameFocusNode.requestFocus();
          break;
        case EditProfileField.phone:
          phoneFocusNode.requestFocus();
          break;
        case EditProfileField.contactEmail:
          contactEmailFocusNode.requestFocus();
          break;
        case EditProfileField.about:
          aboutFocusNode.requestFocus();
          break;
      }
    });
  }

  Future<void> saveProfile() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final contactEmail = contactEmailController.text.trim();
    final about = aboutController.text.trim();

    if (name.isEmpty) return;

    setState(() => isLoading = true);

    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update(
      {
        'name': name,
        'phone': phone,
        'contactEmail': contactEmail,
        'about': about,
      },
    );
    HapticFeedback.mediumImpact();

    if (!mounted) return;

    setState(() => isLoading = false);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    contactEmailController.dispose();
    aboutController.dispose();

    nameFocusNode.dispose();
    phoneFocusNode.dispose();
    contactEmailFocusNode.dispose();
    aboutFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать профиль')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              focusNode: nameFocusNode,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: phoneController,
              focusNode: phoneFocusNode,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Телефон',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contactEmailController,
              focusNode: contactEmailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: aboutController,
              focusNode: aboutFocusNode,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'О себе',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: isLoading ? null : saveProfile,
                child: Text(isLoading ? 'Сохраняем...' : 'Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
