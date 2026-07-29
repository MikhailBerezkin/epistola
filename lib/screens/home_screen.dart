import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/avatar/avatar_image_dependencies.dart';
import '../services/avatar/avatar_replacement_controller.dart';
import '../widgets/avatar_lost_data_recovery_host.dart';
import 'chats_page.dart';
import 'chat_search_screen.dart';
import 'contacts_screen.dart';
import 'new_message_screen.dart';
import 'profile_page.dart';
import 'spaces_page.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AvatarReplacementController _avatarController;
  int selectedIndex = 0;

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
      return const ChatsPage();
    }

    if (selectedIndex == 1) {
      return const SpacesPage();
    }

    if (selectedIndex == 2) {
      return const ContactsScreen();
    }

    return ProfilePage(avatarController: _avatarController);
  }

  void onAddPressed() {
    HapticFeedback.lightImpact();

    if (selectedIndex == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewMessageScreen()),
      );
    } else if (selectedIndex == 1) {
      debugPrint('Создать пространство');
    } else {
      debugPrint('Редактировать профиль');
    }
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

          if (selectedIndex != 0) {
            setState(() {
              selectedIndex = 0;
            });
            return;
          }

          SystemNavigator.pop();
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Epistola'),
            actions: selectedIndex == 0
                ? [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatSearchScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.search),
                      tooltip: 'Поиск',
                    ),
                  ]
                : [],
          ),
          body: getCurrentPage(),
          floatingActionButton: selectedIndex == 0
              ? FloatingActionButton(
                  onPressed: onAddPressed,
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              HapticFeedback.selectionClick();
              setState(() => selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Чаты',
              ),
              NavigationDestination(
                icon: Icon(Icons.hub_outlined),
                selectedIcon: Icon(Icons.hub),
                label: 'Пространства',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Контакты',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Профиль',
              ),
            ],
          ),
        ), // Scaffold
      ), // PopScope
    );
  }
}
