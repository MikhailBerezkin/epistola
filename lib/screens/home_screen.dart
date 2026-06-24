import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'chats_page.dart';
import 'profile_page.dart';
import 'spaces_page.dart';
import 'welcome_screen.dart';
import 'new_message_screen.dart';
import 'chat_search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

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

    return const ProfilePage();
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Epistola'),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();

              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatSearchScreen()),
              );
            },
            icon: const Icon(Icons.search),
            tooltip: 'Поиск',
          ),
          IconButton(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
          ),
        ],
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
