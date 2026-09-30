import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/spaces_tile_id.dart';
import '../platform/epistola_runtime_mode.dart';
import '../services/avatar/avatar_image_dependencies.dart';
import '../services/avatar/avatar_replacement_controller.dart';
import '../widgets/avatar_lost_data_recovery_host.dart';
import 'contacts_screen.dart';
import 'profile_page.dart';
import 'spaces_page.dart';
import 'welcome_screen.dart';

enum _SpacesTileLayoutMode { grid, large }

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

  static const String _spacesTileLayoutModeKey = 'spaces_tile_layout_mode';

  static const String _spacesVisibleTilesKey = 'spaces_visible_tiles';

  static const String _spacesTileOrderKey = 'spaces_tile_order';

  late final AvatarReplacementController _avatarController;

  int selectedIndex = _spacesIndex;

  _SpacesTileLayoutMode _spacesTileLayoutMode = _SpacesTileLayoutMode.grid;

  Set<SpacesTileId> _visibleSpacesTiles = SpacesTileId.values.toSet();

  List<SpacesTileId> _spacesTileOrder = List<SpacesTileId>.of(
    SpacesTileId.values,
  );

  @override
  void initState() {
    super.initState();

    _avatarController = createAvatarReplacementController(
      webContextProvider: () => context,
    );

    _loadSpacesTileLayoutMode();
    _loadVisibleSpacesTiles();
    _loadSpacesTileOrder();
  }

  @override
  void dispose() {
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _loadSpacesTileLayoutMode() async {
    final preferences = await SharedPreferences.getInstance();

    final storedValue = preferences.getString(_spacesTileLayoutModeKey);

    final mode = switch (storedValue) {
      'large' => _SpacesTileLayoutMode.large,
      _ => _SpacesTileLayoutMode.grid,
    };

    if (!mounted) {
      return;
    }

    setState(() {
      _spacesTileLayoutMode = mode;
    });
  }

  Future<void> _setSpacesTileLayoutMode(_SpacesTileLayoutMode mode) async {
    if (_spacesTileLayoutMode == mode) {
      return;
    }

    setState(() {
      _spacesTileLayoutMode = mode;
    });

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_spacesTileLayoutModeKey, switch (mode) {
      _SpacesTileLayoutMode.grid => 'grid',
      _SpacesTileLayoutMode.large => 'large',
    });
  }

  Future<void> _loadVisibleSpacesTiles() async {
    final preferences = await SharedPreferences.getInstance();

    final storedValues = preferences.getStringList(_spacesVisibleTilesKey);

    if (storedValues == null || storedValues.isEmpty) {
      return;
    }

    final restoredTiles = <SpacesTileId>{};

    for (final value in storedValues) {
      for (final tile in SpacesTileId.values) {
        if (tile.name == value) {
          restoredTiles.add(tile);
          break;
        }
      }
    }

    if (restoredTiles.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _visibleSpacesTiles = restoredTiles;
    });
  }

  Future<void> _setVisibleSpacesTiles(Set<SpacesTileId> tiles) async {
    if (tiles.isEmpty) {
      return;
    }

    setState(() {
      _visibleSpacesTiles = Set<SpacesTileId>.from(tiles);
    });

    final preferences = await SharedPreferences.getInstance();

    await preferences.setStringList(
      _spacesVisibleTilesKey,
      SpacesTileId.values
          .where(tiles.contains)
          .map((tile) => tile.name)
          .toList(growable: false),
    );
  }

  Future<void> _loadSpacesTileOrder() async {
    final preferences = await SharedPreferences.getInstance();

    final storedValues = preferences.getStringList(_spacesTileOrderKey);

    if (storedValues == null || storedValues.isEmpty) {
      return;
    }

    final restoredOrder = <SpacesTileId>[];

    for (final value in storedValues) {
      for (final tile in SpacesTileId.values) {
        if (tile.name == value && !restoredOrder.contains(tile)) {
          restoredOrder.add(tile);
          break;
        }
      }
    }

    for (final tile in SpacesTileId.values) {
      if (!restoredOrder.contains(tile)) {
        restoredOrder.add(tile);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _spacesTileOrder = restoredOrder;
    });
  }

  Future<void> _setSpacesTileOrder(List<SpacesTileId> order) async {
    if (order.isEmpty) {
      return;
    }

    setState(() {
      _spacesTileOrder = List<SpacesTileId>.of(order);
    });

    final preferences = await SharedPreferences.getInstance();

    await preferences.setStringList(
      _spacesTileOrderKey,
      order.map((tile) => tile.name).toList(growable: false),
    );
  }

  Future<void> logout(BuildContext context) async {
    HapticFeedback.mediumImpact();

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) {
      return;
    }

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
        useLargeTiles: _spacesTileLayoutMode == _SpacesTileLayoutMode.large,
        visibleTileIds: _visibleSpacesTiles,
        tileOrder: _spacesTileOrder,
      );
    }

    return ProfilePage(avatarController: _avatarController);
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
          if (didPop) {
            return;
          }

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
                        _showSpacesSettings(context);
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

              setState(() {
                selectedIndex = index;
              });
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

  Future<void> _showSpacesSettings(BuildContext context) async {
    final selectedMode = await showModalBottomSheet<_SpacesTileLayoutMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Настройка пространств',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Вид плиток',
                    style: Theme.of(sheetContext).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(Icons.grid_view_outlined),
                  title: const Text('Сетка'),
                  subtitle: const Text('Две плитки в ряд'),
                  trailing: _spacesTileLayoutMode == _SpacesTileLayoutMode.grid
                      ? Icon(Icons.check_circle, color: colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop(_SpacesTileLayoutMode.grid);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.view_agenda_outlined),
                  title: const Text('Крупные плитки'),
                  subtitle: const Text('Одна широкая плитка в ряд'),
                  trailing: _spacesTileLayoutMode == _SpacesTileLayoutMode.large
                      ? Icon(Icons.check_circle, color: colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop(_SpacesTileLayoutMode.large);
                  },
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: const Text('Показывать плитки'),
                  subtitle: Text(
                    '${_visibleSpacesTiles.length} из '
                    '${SpacesTileId.values.length}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    Future<void>.delayed(Duration.zero, () {
                      if (!context.mounted) {
                        return;
                      }

                      _showVisibleSpacesTilesSettings(context);
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.swap_vert),
                  title: const Text('Порядок плиток'),
                  subtitle: const Text('Изменить порядок'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    Future<void>.delayed(Duration.zero, () {
                      if (!context.mounted) {
                        return;
                      }

                      _showSpacesTileOrderSettings(context);
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedMode == null) {
      return;
    }

    await _setSpacesTileLayoutMode(selectedMode);
  }

  Future<void> _showVisibleSpacesTilesSettings(BuildContext context) async {
    var draftSelection = Set<SpacesTileId>.from(_visibleSpacesTiles);

    final result = await showModalBottomSheet<Set<SpacesTileId>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Показывать плитки',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Выберите пространства, '
                        'которые хотите видеть '
                        'на главном экране.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final tile in SpacesTileId.values)
                      CheckboxListTile(
                        value: draftSelection.contains(tile),
                        title: Text(tile.title),
                        controlAffinity: ListTileControlAffinity.trailing,
                        onChanged: (selected) {
                          if (selected == null) {
                            return;
                          }

                          if (!selected &&
                              draftSelection.length == 1 &&
                              draftSelection.contains(tile)) {
                            ScaffoldMessenger.of(sheetContext)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Хотя бы одна плитка '
                                    'должна остаться.',
                                  ),
                                ),
                              );

                            return;
                          }

                          setSheetState(() {
                            if (selected) {
                              draftSelection.add(tile);
                            } else {
                              draftSelection.remove(tile);
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop(draftSelection);
                      },
                      child: const Text('Готово'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    await _setVisibleSpacesTiles(result);
  }

  Future<void> _showSpacesTileOrderSettings(BuildContext context) async {
    var draftOrder = List<SpacesTileId>.of(_spacesTileOrder);

    final result = await showModalBottomSheet<List<SpacesTileId>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.72,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Порядок плиток',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Перетащите плитки '
                          'в нужном порядке.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: draftOrder.length,
                          onReorderItem: (oldIndex, newIndex) {
                            setSheetState(() {
                              final tile = draftOrder.removeAt(oldIndex);

                              draftOrder.insert(newIndex, tile);
                            });
                          },
                          itemBuilder: (context, index) {
                            final tile = draftOrder[index];

                            final isVisible = _visibleSpacesTiles.contains(
                              tile,
                            );

                            return ListTile(
                              key: ValueKey(tile),
                              leading: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                              title: Text(tile.title),
                              subtitle: isVisible ? null : const Text('Скрыта'),
                              trailing: isVisible
                                  ? const Icon(Icons.visibility_outlined)
                                  : const Icon(Icons.visibility_off_outlined),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop(draftOrder);
                        },
                        child: const Text('Готово'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    await _setSpacesTileOrder(result);
  }
}
