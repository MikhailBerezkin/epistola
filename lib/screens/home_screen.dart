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
    final isSpacesSelected = selectedIndex == _spacesIndex;
    final colorScheme = Theme.of(context).colorScheme;

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
            toolbarHeight: isSpacesSelected ? 64 : null,
            title: isSpacesSelected
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Epistola',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Пространства',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : const Text('Epistola'),
            actions: isSpacesSelected
                ? [
                    IconButton(
                      tooltip: 'Настроить пространства',
                      onPressed: () {
                        _showSpacesSettingsPlaceholder(context);
                      },
                      icon: const Icon(Icons.more_vert),
                    ),
                  ]
                : null,
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

  Future<void> _showSpacesSettingsPlaceholder(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Настройка пространств',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Выбор отображаемых плиток добавим следующим этапом.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
