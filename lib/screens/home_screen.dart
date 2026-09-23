import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../platform/epistola_runtime_mode.dart';
import '../services/avatar/avatar_image_dependencies.dart';
import '../services/avatar/avatar_replacement_controller.dart';
import '../widgets/avatar_lost_data_recovery_host.dart';
import 'contacts_screen.dart';
import 'profile_page.dart';
import 'spaces_page.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.spacesBarTargetMessageId,
    this.allowRoutePop = false,
  });

  final String? spacesBarTargetMessageId;
  final bool allowRoutePop;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _spacesIndex = 1;
  static const int _profileIndex = 2;

  late final AvatarReplacementController _avatarController;
  int selectedIndex = _spacesIndex;

  @override
  void initState() {
    super.initState();
    _avatarController = createAvatarReplacementController(
      webContextProvider: () => context,
    );
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
      return SpacesPage(
        spacesBarTargetMessageId: widget.spacesBarTargetMessageId,
      );
    }

    return ProfilePage(avatarController: _avatarController);
  }

  Widget _buildCurrentPageWithCrewNotice() {
    final currentPage = getCurrentPage();

    if (selectedIndex == _profileIndex) {
      return currentPage;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    if (userId.isEmpty) {
      return currentPage;
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final document = snapshot.data;

        if (document == null || !document.exists) {
          return currentPage;
        }

        final profileUser = AppUser.fromFirestore(document);

        if (profileUser.assignedCrew != null) {
          return currentPage;
        }

        return Column(
          children: [
            MaterialBanner(
              leading: const Icon(Icons.groups_2_outlined),
              content: const Text('Вы не выбрали ваше звено'),
              actions: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();

                    setState(() {
                      selectedIndex = _profileIndex;
                    });
                  },
                  child: const Text('Перейти в профиль'),
                ),
              ],
            ),
            Expanded(child: currentPage),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isSpacesSelected = selectedIndex == _spacesIndex;
    final colorScheme = Theme.of(context).colorScheme;
    final appTitle = EpistolaRuntimeMode.appTitle;

    return AvatarLostDataRecoveryHost(
      uid: uid,
      controller: _avatarController,
      coordinator: defaultAvatarLostDataRecoveryCoordinator,
      child: PopScope(
        canPop: widget.allowRoutePop,
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
                        appTitle,
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
                : Text(appTitle),
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
          body: _buildCurrentPageWithCrewNotice(),
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
