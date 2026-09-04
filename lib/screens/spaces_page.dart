import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/models/spaces_access_role.dart';
import '../services/spaces/spaces_bar/spaces_bar_dependencies.dart';
import '../services/spaces/spaces_bar/spaces_bar_management_service.dart';
import '../services/spaces/spaces_bar/spaces_bar_presentation_service.dart';
import '../services/spaces/spaces_dependencies.dart';
import '../widgets/spaces/spaces_bar/spaces_bar_editor_sheet.dart';
import '../widgets/spaces/spaces_bar/spaces_bar_panel.dart';
import 'chats_space_screen.dart';
import 'substitution_space_screen.dart';

class SpacesPage extends StatefulWidget {
  const SpacesPage({super.key, this.spacesBarTargetMessageId});

  final String? spacesBarTargetMessageId;

  @override
  State<SpacesPage> createState() => _SpacesPageState();
}

class _SpacesPageState extends State<SpacesPage> with WidgetsBindingObserver {
  late final SpacesBarPresentationService _spacesBarService;
  late final SpacesBarManagementService _spacesBarManagementService;

  StreamSubscription<SpacesBarPresentationState>? _spacesBarSubscription;
  Timer? _spacesBarExpiryTimer;

  SpacesBarPresentationState? _spacesBarState;
  bool _isSpacesBarLoading = true;
  Object? _spacesBarError;

  SpacesAccessRole _accessRole = SpacesAccessRole.member;
  bool _isAccessRoleLoading = true;

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _spacesBarService = createSpacesBarPresentationService();
    _spacesBarManagementService = createSpacesBarManagementService();

    unawaited(_loadSpacesAccessRole());
    unawaited(_startSpacesBarWatch());
  }

  Future<void> _loadSpacesAccessRole() async {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _accessRole = SpacesAccessRole.member;
        _isAccessRoleLoading = false;
      });

      return;
    }

    try {
      final role = await defaultSpacesAccessService.getRole(userId: userId);

      if (!mounted) {
        return;
      }

      setState(() {
        _accessRole = role;
        _isAccessRoleLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _accessRole = SpacesAccessRole.member;
        _isAccessRoleLoading = false;
      });
    }
  }

  Future<void> _startSpacesBarWatch() async {
    final userId = _currentUserId;

    await _spacesBarSubscription?.cancel();
    _spacesBarSubscription = null;

    _spacesBarExpiryTimer?.cancel();
    _spacesBarExpiryTimer = null;

    if (!mounted) {
      return;
    }

    if (userId.isEmpty) {
      setState(() {
        _spacesBarState = null;
        _spacesBarError = null;
        _isSpacesBarLoading = false;
      });

      return;
    }

    setState(() {
      _isSpacesBarLoading = true;
      _spacesBarError = null;
    });

    _spacesBarSubscription = _spacesBarService
        .watch(userId: userId)
        .listen(
          (state) {
            if (!mounted) {
              return;
            }

            setState(() {
              _spacesBarState = state;
              _spacesBarError = null;
              _isSpacesBarLoading = false;
            });

            _scheduleSpacesBarExpiry(state);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) {
              return;
            }

            setState(() {
              _spacesBarError = error;
              _isSpacesBarLoading = false;
            });
          },
        );
  }

  void _scheduleSpacesBarExpiry(SpacesBarPresentationState state) {
    _spacesBarExpiryTimer?.cancel();
    _spacesBarExpiryTimer = null;

    final expiryAtLocal = state.nextSubstitutionExpiryAtLocal;

    if (expiryAtLocal == null) {
      return;
    }

    final delay = expiryAtLocal.difference(DateTime.now());

    if (delay <= Duration.zero) {
      _refreshSpacesBarForCurrentTime();
      return;
    }

    _spacesBarExpiryTimer = Timer(delay, _refreshSpacesBarForCurrentTime);
  }

  void _refreshSpacesBarForCurrentTime() {
    if (!mounted) {
      return;
    }

    final currentState = _spacesBarState;

    if (currentState == null) {
      return;
    }

    final nextState = _spacesBarService.refreshForCurrentTime(
      currentState: currentState,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _spacesBarState = nextState;
    });

    _scheduleSpacesBarExpiry(nextState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    _refreshSpacesBarForCurrentTime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _spacesBarExpiryTimer?.cancel();
    _spacesBarExpiryTimer = null;

    unawaited(_spacesBarSubscription?.cancel());

    super.dispose();
  }

  Future<void> _hideSpacesBarMessage(String messageId) async {
    final userId = _currentUserId;
    final currentState = _spacesBarState;

    if (userId.isEmpty || currentState == null) {
      return;
    }

    try {
      final nextState = await _spacesBarService.hideMessage(
        userId: userId,
        messageId: messageId,
        currentState: currentState,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _spacesBarState = nextState;
      });
      _scheduleSpacesBarExpiry(nextState);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSpacesBarSnackBar('Не удалось убрать сообщение.');
    }
  }

  Future<void> _hideSpacesBarSubstitutionCall(String callId) async {
    final userId = _currentUserId;
    final currentState = _spacesBarState;

    if (userId.isEmpty || currentState == null) {
      return;
    }

    try {
      final nextState = await _spacesBarService.hideSubstitutionCall(
        userId: userId,
        callId: callId,
        currentState: currentState,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _spacesBarState = nextState;
      });
      _scheduleSpacesBarExpiry(nextState);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSpacesBarSnackBar('Не удалось убрать вызов.');
    }
  }

  Future<void> _openSpacesBarEditor() async {
    final userId = _currentUserId;
    final currentState = _spacesBarState;

    if (_isAccessRoleLoading ||
        !_accessRole.canManageSpacesBar ||
        userId.isEmpty ||
        currentState == null) {
      return;
    }

    final action = await showModalBottomSheet<SpacesBarEditorAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SpacesBarEditorSheet(
          activeMessages: currentState.activeMessages,
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action is SpacesBarEditorPublishAction) {
      await _publishSpacesBarMessage(userId: userId, action: action);

      return;
    }

    if (action is SpacesBarEditorDeleteAction) {
      await _deleteSpacesBarMessage(action: action);
    }
  }

  Future<void> _publishSpacesBarMessage({
    required String userId,
    required SpacesBarEditorPublishAction action,
  }) async {
    try {
      await _spacesBarManagementService.publish(
        role: _accessRole,
        text: action.text,
        lifetime: action.lifetime,
        createdByUserId: userId,
      );

      if (!mounted) {
        return;
      }

      _showSpacesBarSnackBar('Сообщение опубликовано.');
    } on SpacesBarManagementPermissionException {
      if (!mounted) {
        return;
      }

      _showSpacesBarSnackBar('Нет доступа к публикации сообщений.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSpacesBarSnackBar('Не удалось опубликовать сообщение.');
    }
  }

  Future<void> _deleteSpacesBarMessage({
    required SpacesBarEditorDeleteAction action,
  }) async {
    try {
      final deleted = await _spacesBarManagementService.deleteMessage(
        role: _accessRole,
        messageId: action.messageId,
      );

      if (!mounted) {
        return;
      }
      _showSpacesBarSnackBar(
        deleted ? 'Сообщение удалено для всех.' : 'Сообщение уже отсутствует.',
      );
    } on SpacesBarManagementPermissionException {
      if (!mounted) {
        return;
      }

      _showSpacesBarSnackBar('Нет доступа к удалению сообщений.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSpacesBarSnackBar('Не удалось удалить сообщение.');
    }
  }

  void _showSpacesBarSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final presentationItems = _spacesBarState?.presentationItems ?? const [];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _startSpacesBarWatch,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: SpacesBarPanel(
                  items: presentationItems,
                  targetMessageId: widget.spacesBarTargetMessageId,
                  isLoading: _isSpacesBarLoading,
                  error: _spacesBarError,
                  onRetry: () {
                    unawaited(_startSpacesBarWatch());
                  },
                  onHideMessage: _hideSpacesBarMessage,
                  onHideSubstitutionCall: _hideSpacesBarSubstitutionCall,
                  canManage:
                      !_isAccessRoleLoading && _accessRole.canManageSpacesBar,
                  onEdit:
                      !_isAccessRoleLoading && _accessRole.canManageSpacesBar
                      ? _openSpacesBarEditor
                      : null,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildListDelegate([
                  _SpaceTile(
                    title: 'Чаты',
                    subtitle: 'Личные и групповые чаты',
                    icon: Icons.forum_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChatsSpaceScreen(),
                        ),
                      );
                    },
                  ),
                  _SpaceTile(
                    title: '"Список"',
                    icon: Icons.groups_2_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SubstitutionSpaceScreen(),
                        ),
                      );
                    },
                  ),
                  _SpaceTile(
                    title: 'Судозаходы',
                    subtitle: 'Суда и объём работ',
                    icon: Icons.directions_boat_outlined,
                    onTap: () {
                      _showUnderDevelopment(context, 'Судозаходы');
                    },
                  ),
                  _SpaceTile(
                    title: 'Календарь смен',
                    subtitle: 'Смены и рабочие события',
                    icon: Icons.calendar_month_outlined,
                    onTap: () {
                      _showUnderDevelopment(context, 'Календарь смен');
                    },
                  ),
                  _SpaceTile(
                    title: 'Автобусы',
                    subtitle: 'Расписание транспорта',
                    icon: Icons.directions_bus_outlined,
                    onTap: () {
                      _showUnderDevelopment(context, 'Автобусы');
                    },
                  ),
                  _SpaceTile(
                    title: 'ОТ и ТБ',
                    subtitle: 'Инструкции и поиск',
                    icon: Icons.health_and_safety_outlined,
                    onTap: () {
                      _showUnderDevelopment(context, 'ОТ и ТБ');
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUnderDevelopment(BuildContext context, String title) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: const Text('Раздел пока в разработке.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('ОК'),
            ),
          ],
        );
      },
    );
  }
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: colorScheme.primary),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
