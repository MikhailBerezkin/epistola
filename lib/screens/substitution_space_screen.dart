import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/models/spaces_access_role.dart';
import '../domain/models/substitution_call_receipt.dart';
import '../domain/models/substitution_participant.dart';
import '../models/app_user.dart';
import '../services/spaces/spaces_dependencies.dart';
import '../services/spaces/substitution/substitution_call_service.dart';
import '../services/spaces/substitution/substitution_dependencies.dart';
import '../services/spaces/substitution/substitution_participant_actions_service.dart';
import '../services/spaces/substitution/substitution_participants_service.dart';
import '../services/spaces/substitution/substitution_user_cache.dart';
import '../widgets/spaces/substitution/substitution_participant_overlay.dart';
import '../widgets/spaces/substitution/substitution_participant_row.dart';
import '../widgets/spaces/substitution/substitution_queue_badge.dart';
import '../widgets/spaces/substitution/substitution_settings_sheet.dart';
import 'substitution_add_participants_screen.dart';
import '../services/spaces/substitution/substitution_work_display_name_service.dart';
import '../services/spaces/substitution/substitution_ui_preferences.dart';
import '../domain/models/substitution_test_statistics.dart';
import '../services/spaces/substitution/substitution_test_statistics_service.dart';
import '../domain/models/substitution_shift.dart';

class SubstitutionSpaceScreen extends StatefulWidget {
  const SubstitutionSpaceScreen({super.key});

  @override
  State<SubstitutionSpaceScreen> createState() =>
      _SubstitutionSpaceScreenState();
}

class _SubstitutionSpaceScreenState extends State<SubstitutionSpaceScreen>
    with SingleTickerProviderStateMixin {
  late final SubstitutionParticipantsService _participantsService;
  late final SubstitutionUserCache _userCache;
  late final SubstitutionCallService _callService;
  late final SubstitutionParticipantActionsService _participantActionsService;
  late final SubstitutionWorkDisplayNameService _workDisplayNameService;
  late final SubstitutionUiPreferences _uiPreferences;
  late final SubstitutionTestStatisticsService _testStatisticsService;
  late final TabController _tabController;

  int _currentTabIndex = 0;
  SubstitutionQueueDisplayMode _queueDisplayMode =
      SubstitutionQueueDisplayMode.numberOnly;

  bool _showStatistics = false;

  SubstitutionTestStatistics? _testStatistics;
  bool _isTestStatisticsLoading = false;
  Object? _testStatisticsError;

  SpacesAccessRole _accessRole = SpacesAccessRole.member;

  bool _isAccessRoleLoading = true;
  bool _isRotationActionInProgress = false;
  bool _isAvailabilityActionInProgress = false;
  bool _isWorkDisplayNameActionInProgress = false;

  StreamSubscription<List<SubstitutionParticipant>>? _participantsSubscription;

  List<SubstitutionParticipant> _participants =
      const <SubstitutionParticipant>[];

  bool _isLoading = true;

  Object? _participantsError;
  Object? _usersError;

  String? _selectedParticipantId;
  bool _isParticipantOverlayOpen = false;

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  }

  bool get _isActionInProgress {
    return _isRotationActionInProgress ||
        _isAvailabilityActionInProgress ||
        _isWorkDisplayNameActionInProgress;
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);

    _participantsService = SubstitutionParticipantsService.firebase();
    _userCache = SubstitutionUserCache.firebase();
    _callService = createSubstitutionCallService();
    _participantActionsService = createSubstitutionParticipantActionsService();
    _workDisplayNameService = createSubstitutionWorkDisplayNameService();
    _testStatisticsService = createSubstitutionTestStatisticsService();
    _uiPreferences = SubstitutionUiPreferences();

    unawaited(_loadAccessRole());
    unawaited(_loadUiPreferences());
    _watchParticipants();
  }

  void _handleTabChanged() {
    final index = _tabController.index;

    if (_currentTabIndex == index) {
      return;
    }

    setState(() {
      _currentTabIndex = index;
    });
  }

  void _goToParticipantList() {
    if (_tabController.index == 0) {
      return;
    }

    _tabController.animateTo(0);
  }

  void _handleAppBarBack() {
    if (_isParticipantOverlayOpen) {
      _closeParticipantCard();
      return;
    }

    if (_currentTabIndex != 0) {
      _goToParticipantList();
      return;
    }

    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    final subscription = _participantsSubscription;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();

    super.dispose();
  }

  Future<void> _loadAccessRole() async {
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

  Future<void> _loadUiPreferences() async {
    try {
      final preferences = await _uiPreferences.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _queueDisplayMode = preferences.useNumberOnly
            ? SubstitutionQueueDisplayMode.numberOnly
            : SubstitutionQueueDisplayMode.avatarWithNumber;

        _showStatistics = preferences.showStatistics;
      });
      if (preferences.showStatistics) {
        await _ensureTestStatisticsLoaded();
      }
    } catch (_) {
      // Локальные настройки не должны мешать работе Подсменки.
      // При ошибке остаются значения по умолчанию.
    }
  }

  void _setQueueDisplayMode(SubstitutionQueueDisplayMode mode) {
    if (_queueDisplayMode == mode) {
      return;
    }

    setState(() {
      _queueDisplayMode = mode;
    });

    unawaited(_saveQueueDisplayMode(mode));
  }

  Future<void> _saveQueueDisplayMode(SubstitutionQueueDisplayMode mode) async {
    try {
      await _uiPreferences.saveUseNumberOnly(
        mode == SubstitutionQueueDisplayMode.numberOnly,
      );
    } catch (_) {
      // Сам UI уже переключён. Ошибка локального сохранения
      // не должна блокировать работу Подсменки.
    }
  }

  void _setShowStatistics(bool value) {
    if (_showStatistics == value) {
      return;
    }

    setState(() {
      _showStatistics = value;
    });

    unawaited(_saveShowStatistics(value));

    if (value) {
      unawaited(_ensureTestStatisticsLoaded());
    }
  }

  Future<void> _saveShowStatistics(bool value) async {
    try {
      await _uiPreferences.saveShowStatistics(value);
    } catch (_) {
      // Пока статистика является только UI-настройкой.
    }
  }

  Future<void> _ensureTestStatisticsLoaded() async {
    if (!_showStatistics ||
        _testStatistics != null ||
        _isTestStatisticsLoading) {
      return;
    }

    setState(() {
      _isTestStatisticsLoading = true;
      _testStatisticsError = null;
    });

    try {
      final statistics = await _testStatisticsService.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _testStatistics = statistics;
        _testStatisticsError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _testStatisticsError = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTestStatisticsLoading = false;
        });
      }
    }
  }

  void _retryTestStatistics() {
    if (!_showStatistics || _isTestStatisticsLoading) {
      return;
    }

    setState(() {
      _testStatisticsError = null;
    });

    unawaited(_ensureTestStatisticsLoaded());
  }

  void _watchParticipants() {
    _participantsSubscription = _participantsService.watchParticipants().listen(
      (participants) {
        if (!mounted) {
          return;
        }

        setState(() {
          _participants = participants;
          _isLoading = false;
          _participantsError = null;
        });

        unawaited(_loadMissingUsers(participants));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _participantsError = error;
        });
      },
    );
  }

  Future<void> _loadMissingUsers(
    List<SubstitutionParticipant> participants,
  ) async {
    try {
      final changed = await _userCache.loadMissing(
        participants.map((participant) => participant.userId),
      );

      if (!mounted) {
        return;
      }

      if (changed || _usersError != null) {
        setState(() {
          _usersError = null;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _usersError = error;
      });
    }
  }

  void _retryParticipants() {
    final subscription = _participantsSubscription;

    _participantsSubscription = null;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    setState(() {
      _isLoading = true;
      _participantsError = null;
    });

    _watchParticipants();
  }

  void _retryUsers() {
    setState(() {
      _usersError = null;
    });

    unawaited(_loadMissingUsers(_participants));
  }

  Future<void> _openAddParticipants() async {
    if (_isActionInProgress) {
      return;
    }

    final selectedUsers = await Navigator.of(context).push<List<AppUser>>(
      MaterialPageRoute<List<AppUser>>(
        builder: (_) {
          return SubstitutionAddParticipantsScreen(
            excludedUserIds: _participants
                .map((participant) => participant.userId)
                .toSet(),
          );
        },
      ),
    );

    if (!mounted || selectedUsers == null || selectedUsers.isEmpty) {
      return;
    }

    try {
      final addedCount = await _participantsService.addParticipants(
        selectedUsers.map((user) => user.uid),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount == 1
                ? 'Участник добавлен'
                : 'Добавлено участников: $addedCount',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить участников')),
      );
    }
  }

  Future<void> _openSubstitutionSettings({
    required bool canManageSubstitution,
  }) async {
    if (_isActionInProgress) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SubstitutionSettingsSheet(
          queueDisplayMode: _queueDisplayMode,
          showStatistics: _showStatistics,
          onQueueDisplayModeChanged: _setQueueDisplayMode,
          onShowStatisticsChanged: _setShowStatistics,
          onAddParticipants: canManageSubstitution
              ? () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_openAddParticipants());
                }
              : null,
        );
      },
    );
  }

  Future<void> _editParticipantWorkDisplayName(
    SubstitutionParticipant participant,
    AppUser user,
  ) async {
    if (_isActionInProgress || !_accessRole.canManageSubstitution) {
      return;
    }

    var editedName = user.workDisplayName.trim();
    final defaultName = user.name.trim();

    final newWorkDisplayName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Рабочее имя'),
          content: TextFormField(
            initialValue: editedName,
            autofocus: true,
            maxLength:
                SubstitutionWorkDisplayNameService.maxWorkDisplayNameLength,
            decoration: InputDecoration(
              labelText: 'Имя в подсменке',
              hintText: defaultName.isEmpty ? null : defaultName,
              helperText: 'Пустое поле вернёт обычное имя пользователя',
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              editedName = value;
            },
            onFieldSubmitted: (value) {
              Navigator.of(dialogContext).pop(value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(editedName);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    if (!mounted || newWorkDisplayName == null) {
      return;
    }

    final normalizedName = newWorkDisplayName.trim();

    if (normalizedName == user.workDisplayName.trim()) {
      return;
    }

    setState(() {
      _isWorkDisplayNameActionInProgress = true;
    });

    try {
      await _workDisplayNameService.updateWorkDisplayName(
        userId: participant.userId,
        workDisplayName: normalizedName,
      );

      await _userCache.refresh(participant.userId);

      if (!mounted) {
        return;
      }

      setState(() {});
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить рабочее имя')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorkDisplayNameActionInProgress = false;
        });
      }
    }
  }

  Future<void> _confirmCallParticipant(
    SubstitutionParticipant participant,
  ) async {
    if (!_accessRole.canManageSubstitution ||
        _isActionInProgress ||
        !participant.isActive) {
      return;
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final selectedShift = await showDialog<SubstitutionShift>(
      context: context,
      builder: (dialogContext) {
        const buttonHeight = 48.0;

        return AlertDialog(
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      SubstitutionShift(
                        year: today.year,
                        month: today.month,
                        day: today.day,
                        kind: SubstitutionShiftKind.night,
                      ),
                    );
                  },
                  child: const Text('Сегодня в ночь'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      SubstitutionShift(
                        year: tomorrow.year,
                        month: tomorrow.month,
                        day: tomorrow.day,
                        kind: SubstitutionShiftKind.day,
                      ),
                    );
                  },
                  child: const Text('Завтра в день'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Отмена'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selectedShift == null) {
      return;
    }

    final displayName = _displayNameForParticipant(participant);

    await _callParticipant(
      participant: participant,
      displayName: displayName,
      shift: selectedShift,
    );
  }

  Future<void> _callParticipant({
    required SubstitutionParticipant participant,
    required String displayName,
    required SubstitutionShift shift,
  }) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() {
      _isRotationActionInProgress = true;
    });

    try {
      final receipt = await _callService.callParticipant(
        userId: participant.userId,
        calledByUserId: _currentUserId,
        shift: shift,
      );

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(days: 1),
          content: Text('$displayName вызван'),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () {
              unawaited(_undoLastCall(receipt));
            },
          ),
        ),
      );

      Timer(const Duration(seconds: 6), () {
        if (!mounted) {
          return;
        }

        messenger.hideCurrentSnackBar();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выполнить вызов')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRotationActionInProgress = false;
        });
      }
    }
  }

  Future<void> _undoLastCall(SubstitutionCallReceipt receipt) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() {
      _isRotationActionInProgress = true;
    });

    try {
      final undone = await _callService.undoLastCall(receipt: receipt);

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            undone
                ? 'Вызов отменён'
                : 'Отмена недоступна: очередь уже изменилась',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отменить вызов')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRotationActionInProgress = false;
        });
      }
    }
  }

  Future<void> _updateParticipantAvailability(
    SubstitutionParticipant participant,
    SubstitutionAvailability availability,
  ) async {
    if (_isActionInProgress ||
        !participant.isActive ||
        participant.userId != _currentUserId ||
        participant.availability == availability) {
      return;
    }

    setState(() {
      _isAvailabilityActionInProgress = true;
    });

    try {
      await _participantActionsService.updateAvailability(
        userId: participant.userId,
        availability: availability,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить доступность')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAvailabilityActionInProgress = false;
        });
      }
    }
  }

  Future<void> _updateParticipantStatus(
    SubstitutionParticipant participant,
    SubstitutionParticipantStatus status,
  ) async {
    if (_isActionInProgress ||
        !_accessRole.canManageSubstitution ||
        participant.status == status) {
      return;
    }

    setState(() {
      _isRotationActionInProgress = true;
    });

    try {
      await _participantActionsService.updateStatus(
        userId: participant.userId,
        status: status,
      );

      if (!mounted) {
        return;
      }

      _closeParticipantCard();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить статус участника')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRotationActionInProgress = false;
        });
      }
    }
  }

  Future<void> _confirmRemoveParticipant(
    SubstitutionParticipant participant,
  ) async {
    if (_isActionInProgress || !_accessRole.canManageSubstitution) {
      return;
    }

    final displayName = _displayNameForParticipant(participant);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить участника?'),
          content: Text(
            '$displayName будет удалён из подсменки. '
            'Позже его можно будет добавить снова.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await _removeParticipant(participant, displayName: displayName);
  }

  Future<void> _removeParticipant(
    SubstitutionParticipant participant, {
    required String displayName,
  }) async {
    if (_isActionInProgress || !_accessRole.canManageSubstitution) {
      return;
    }

    setState(() {
      _isRotationActionInProgress = true;
    });

    try {
      await _participantActionsService.removeParticipant(
        userId: participant.userId,
      );

      if (!mounted) {
        return;
      }

      _closeParticipantCard();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$displayName удалён из подсменки')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить участника')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRotationActionInProgress = false;
        });
      }
    }
  }

  void _openParticipantCard(SubstitutionParticipant participant) {
    setState(() {
      _selectedParticipantId = participant.userId;
      _isParticipantOverlayOpen = true;
    });
  }

  void _closeParticipantCard() {
    if (!_isParticipantOverlayOpen) {
      return;
    }

    setState(() {
      _isParticipantOverlayOpen = false;
    });
  }

  SubstitutionParticipant? _participantById(String? userId) {
    if (userId == null || userId.isEmpty) {
      return null;
    }

    for (final participant in _participants) {
      if (participant.userId == userId) {
        return participant;
      }
    }

    return null;
  }

  int? _queuePositionForParticipant(
    SubstitutionParticipant? participant,
    List<SubstitutionParticipant> activeParticipants,
  ) {
    if (participant == null || !participant.isActive) {
      return null;
    }

    final index = activeParticipants.indexWhere(
      (candidate) => candidate.userId == participant.userId,
    );

    if (index < 0) {
      return null;
    }

    return index + 1;
  }

  String _displayNameForParticipant(SubstitutionParticipant participant) {
    final user = _userCache.usersById[participant.userId];

    if (user == null) {
      return participant.userId;
    }

    final displayName = user.effectiveWorkDisplayName.trim();

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email.trim();

    if (email.isNotEmpty) {
      return email;
    }

    return participant.userId;
  }

  @override
  Widget build(BuildContext context) {
    final activeParticipants = _participants
        .where((participant) => participant.isActive)
        .toList(growable: false);

    final vacationParticipants = _participants
        .where((participant) => participant.isOnVacation)
        .toList(growable: false);

    final sickParticipants = _participants
        .where((participant) => participant.isSick)
        .toList(growable: false);

    final usersById = _userCache.usersById;

    final canManageSubstitution =
        !_isAccessRoleLoading && _accessRole.canManageSubstitution;

    final selectedParticipant = _participantById(_selectedParticipantId);

    final selectedUser = selectedParticipant == null
        ? null
        : usersById[selectedParticipant.userId];

    final selectedQueuePosition = _queuePositionForParticipant(
      selectedParticipant,
      activeParticipants,
    );

    final canChangeSelectedAvailability =
        selectedParticipant != null &&
        selectedParticipant.isActive &&
        selectedParticipant.userId == _currentUserId &&
        !_isActionInProgress;

    return PopScope<Object?>(
      canPop: !_isParticipantOverlayOpen && _currentTabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        if (_isParticipantOverlayOpen) {
          _closeParticipantCard();
          return;
        }

        if (_currentTabIndex != 0) {
          _goToParticipantList();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: _handleAppBarBack),
              title: const Text('Подсменка'),
              actions: [
                IconButton(
                  tooltip: 'Настройки подсменки',
                  onPressed: _isActionInProgress
                      ? null
                      : () {
                          unawaited(
                            _openSubstitutionSettings(
                              canManageSubstitution: canManageSubstitution,
                            ),
                          );
                        },
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Список ${activeParticipants.length}'),
                  Tab(text: 'Отпуск ${vacationParticipants.length}'),
                  Tab(text: 'Больничный ${sickParticipants.length}'),
                ],
              ),
            ),
            body: _buildBody(
              activeParticipants: activeParticipants,
              vacationParticipants: vacationParticipants,
              sickParticipants: sickParticipants,
              usersById: usersById,
              canManageSubstitution: canManageSubstitution,
            ),
          ),
          SubstitutionParticipantOverlay(
            isOpen: _isParticipantOverlayOpen,
            participant: selectedParticipant,
            user: selectedUser,
            queuePosition: selectedQueuePosition,
            monthlyCallCount:
                _showStatistics &&
                    selectedParticipant != null &&
                    _testStatistics != null
                ? _testStatistics!.callsFor(selectedParticipant.userId)
                : null,
            onClose: _closeParticipantCard,
            onEditName:
                canManageSubstitution &&
                    selectedParticipant != null &&
                    selectedUser != null &&
                    !_isActionInProgress
                ? () {
                    unawaited(
                      _editParticipantWorkDisplayName(
                        selectedParticipant,
                        selectedUser,
                      ),
                    );
                  }
                : null,
            onAvailabilityChanged: canChangeSelectedAvailability
                ? (availability) {
                    unawaited(
                      _updateParticipantAvailability(
                        selectedParticipant,
                        availability,
                      ),
                    );
                  }
                : null,
            onVacation:
                canManageSubstitution &&
                    selectedParticipant != null &&
                    selectedParticipant.isActive &&
                    !_isActionInProgress
                ? () {
                    unawaited(
                      _updateParticipantStatus(
                        selectedParticipant,
                        SubstitutionParticipantStatus.vacation,
                      ),
                    );
                  }
                : null,
            onSick:
                canManageSubstitution &&
                    selectedParticipant != null &&
                    selectedParticipant.isActive &&
                    !_isActionInProgress
                ? () {
                    unawaited(
                      _updateParticipantStatus(
                        selectedParticipant,
                        SubstitutionParticipantStatus.sick,
                      ),
                    );
                  }
                : null,
            onReturnToList:
                canManageSubstitution &&
                    selectedParticipant != null &&
                    !selectedParticipant.isActive &&
                    !_isActionInProgress
                ? () {
                    unawaited(
                      _updateParticipantStatus(
                        selectedParticipant,
                        SubstitutionParticipantStatus.active,
                      ),
                    );
                  }
                : null,
            onRemove:
                canManageSubstitution &&
                    selectedParticipant != null &&
                    !_isActionInProgress
                ? () {
                    unawaited(_confirmRemoveParticipant(selectedParticipant));
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required List<SubstitutionParticipant> activeParticipants,
    required List<SubstitutionParticipant> vacationParticipants,
    required List<SubstitutionParticipant> sickParticipants,
    required Map<String, AppUser> usersById,
    required bool canManageSubstitution,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_participantsError != null) {
      return _LoadError(
        text: 'Не удалось загрузить участников',
        onRetry: _retryParticipants,
      );
    }

    return Column(
      children: [
        if (_usersError != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text(
                'Не удалось загрузить данные части пользователей',
              ),
              trailing: TextButton(
                onPressed: _retryUsers,
                child: const Text('Повторить'),
              ),
            ),
          ),
        if (_showStatistics && _isTestStatisticsLoading)
          const LinearProgressIndicator(minHeight: 2),

        if (_showStatistics && _testStatisticsError != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Не удалось загрузить тестовую статистику'),
              trailing: TextButton(
                onPressed: _retryTestStatistics,
                child: const Text('Повторить'),
              ),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ParticipantListTab(
                participants: activeParticipants,
                usersById: usersById,
                emptyText: 'В ротации пока нет участников',
                showQueueNumber: true,
                queueDisplayMode: _queueDisplayMode,
                showStatistics: _showStatistics,
                statistics: _testStatistics,
                onCall: canManageSubstitution && !_isActionInProgress
                    ? (participant) {
                        unawaited(_confirmCallParticipant(participant));
                      }
                    : null,
                onOpenCard: _openParticipantCard,
              ),
              _ParticipantListTab(
                participants: vacationParticipants,
                usersById: usersById,
                emptyText: 'В отпуске никого нет',
                showQueueNumber: false,
                queueDisplayMode: _queueDisplayMode,
                showStatistics: _showStatistics,
                statistics: _testStatistics,
                onOpenCard: _openParticipantCard,
              ),
              _ParticipantListTab(
                participants: sickParticipants,
                usersById: usersById,
                emptyText: 'На больничном никого нет',
                showQueueNumber: false,
                queueDisplayMode: _queueDisplayMode,
                showStatistics: _showStatistics,
                statistics: _testStatistics,
                onOpenCard: _openParticipantCard,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantListTab extends StatelessWidget {
  const _ParticipantListTab({
    required this.participants,
    required this.usersById,
    required this.emptyText,
    required this.showQueueNumber,
    required this.queueDisplayMode,
    required this.showStatistics,
    required this.statistics,
    required this.onOpenCard,
    this.onCall,
  });

  final List<SubstitutionParticipant> participants;
  final Map<String, AppUser> usersById;

  final String emptyText;
  final bool showQueueNumber;
  final SubstitutionQueueDisplayMode queueDisplayMode;
  final bool showStatistics;
  final SubstitutionTestStatistics? statistics;

  final ValueChanged<SubstitutionParticipant> onOpenCard;
  final ValueChanged<SubstitutionParticipant>? onCall;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return _EmptySubstitutionTab(text: emptyText);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: participants.length,
      separatorBuilder: (context, index) {
        return const Divider(height: 1, indent: 72);
      },
      itemBuilder: (context, index) {
        final participant = participants[index];
        final user = usersById[participant.userId];

        return SubstitutionParticipantRow(
          participant: participant,
          user: user,
          queuePosition: showQueueNumber ? index + 1 : null,
          queueDisplayMode: queueDisplayMode,
          statisticsCount: showStatistics && statistics != null
              ? statistics!.callsFor(participant.userId)
              : null,
          onCall: onCall == null
              ? null
              : () {
                  onCall!(participant);
                },
          onOpenCard: () {
            onOpenCard(participant);
          },
        );
      },
    );
  }
}

class _EmptySubstitutionTab extends StatelessWidget {
  const _EmptySubstitutionTab({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
