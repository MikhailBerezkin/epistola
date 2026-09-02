import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/avatar/avatar_image_dependencies.dart';
import '../services/avatar/avatar_replacement_controller.dart';
import '../widgets/avatar_lost_data_recovery_host.dart';
import 'contacts_screen.dart';
import 'profile_page.dart';
import 'spaces_page.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _spacesIndex = 1;

  late final AvatarReplacementController _avatarController;
  int selectedIndex = _spacesIndex;

  @override
  void initState() {
    super.initState();
    _avatarController = createAvatarReplacementController();
  }

  @override
  void dispose() {
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> logout(BuildContext context) async {
    HapticFeedback.mediumImpact();

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Widget getCurrentPage() {
    if (selectedIndex == 0) {
      return const ContactsScreen();
    }

    if (selectedIndex == _spacesIndex) {
      return const SpacesPage();
    }

    return ProfilePage(avatarController: _avatarController);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return AvatarLostDataRecoveryHost(
      uid: uid,
      controller: _avatarController,
      coordinator: defaultAvatarLostDataRecoveryCoordinator,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          if (selectedIndex != _spacesIndex) {
            setState(() {
              selectedIndex = _spacesIndex;
            });
            return;
          }

          SystemNavigator.pop();
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Epistola'),
          ),
          body: getCurrentPage(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              HapticFeedback.selectionClick();
              setState(() => selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Контакты',
              ),
              NavigationDestination(
                icon: Icon(Icons.hub_outlined),
                selectedIcon: Icon(Icons.hub),
                label: 'Пространства',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
