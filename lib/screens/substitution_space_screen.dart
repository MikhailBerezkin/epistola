import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/models/spaces_access_role.dart';
import '../domain/models/substitution_call_receipt.dart';
import '../domain/models/substitution_participant.dart';
import '../domain/models/substitution_rotation_draft.dart';
import '../domain/models/shift_cycle.dart';
import '../models/app_user.dart';
import '../services/spaces/spaces_dependencies.dart';
import '../services/spaces/substitution/substitution_call_service.dart';
import '../services/spaces/substitution/substitution_call_reconciliation_service.dart';
import '../services/spaces/substitution/substitution_dependencies.dart';
import '../services/spaces/substitution/substitution_participant_actions_service.dart';
import '../services/spaces/substitution/substitution_participants_service.dart';
import '../services/spaces/substitution/substitution_user_cache.dart';
import '../services/spaces/substitution/substitution_work_profile_service.dart';
import '../widgets/spaces/substitution/substitution_participant_overlay.dart';
import '../widgets/spaces/substitution/substitution_participant_row.dart';
import '../widgets/spaces/substitution/substitution_queue_badge.dart';
import '../widgets/spaces/substitution/substitution_settings_sheet.dart';
import 'substitution_add_participants_screen.dart';
import '../services/spaces/substitution/substitution_work_display_name_service.dart';
import '../services/spaces/substitution/substitution_ui_preferences.dart';
import '../domain/models/substitution_statistics.dart';
import '../services/spaces/substitution/substitution_statistics_service.dart';
import '../domain/models/substitution_shift.dart';
import '../services/spaces/substitution/substitution_rotation_edit_service.dart';
import '../services/spaces/substitution/substitution_shift_call_claim.dart';
import '../domain/models/vacation_period.dart';
import '../services/spaces/calendar/vacation_period_service.dart';
import '../services/spaces/substitution/substitution_effective_status_resolver.dart';
import 'vacation_periods_screen.dart';
import '../services/spaces/substitution/substitution_call_eligibility_resolver.dart';

final class _SubstitutionWorkProfileEditResult {
  const _SubstitutionWorkProfileEditResult({
    required this.workDisplayName,
    required this.crew,
  });

  final String workDisplayName;
  final ShiftCrew? crew;
}

class SubstitutionSpaceScreen extends StatefulWidget {
  const SubstitutionSpaceScreen({super.key});

  @override
  State<SubstitutionSpaceScreen> createState() =>
      _SubstitutionSpaceScreenState();
}

class _SubstitutionSpaceScreenState extends State<SubstitutionSpaceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final SubstitutionParticipantsService _participantsService;
  late final SubstitutionUserCache _userCache;
  late final SubstitutionCallService _callService;
  late final SubstitutionCallReconciliationService _callReconciliationService;
  late final SubstitutionParticipantActionsService _participantActionsService;
  late final SubstitutionWorkDisplayNameService _workDisplayNameService;
  late final SubstitutionWorkProfileService _workProfileService;
  late final SubstitutionUiPreferences _uiPreferences;
  late final SubstitutionStatisticsService _statisticsService;
  late final TabController _tabController;
  late final SubstitutionRotationEditService _rotationEditService;
  late final VacationPeriodService _vacationPeriodService;

  final SubstitutionEffectiveStatusResolver _effectiveStatusResolver =
      const SubstitutionEffectiveStatusResolver();

  final SubstitutionCallEligibilityResolver _callEligibilityResolver =
      const SubstitutionCallEligibilityResolver();

  int _currentTabIndex = 0;
  SubstitutionQueueDisplayMode _queueDisplayMode =
      SubstitutionQueueDisplayMode.numberOnly;

  bool _showStatistics = false;
  SubstitutionRotationDraft? _rotationDraft;
  SubstitutionRotationEditBaseline? _rotationEditBaseline;

  bool _isRotationEditApplying = false;

  bool get _isRotationEditing => _rotationDraft != null;

  SubstitutionStatistics? _statistics;
  bool _statisticsLoaded = false;
  bool _isStatisticsLoading = false;
  Object? _statisticsError;
  int? _statisticsYear;

  SpacesAccessRole _accessRole = SpacesAccessRole.member;

  bool _isAccessRoleLoading = true;
  bool _isRotationActionInProgress = false;
  bool _isAvailabilityActionInProgress = false;
  bool _isWorkDisplayNameActionInProgress = false;

  StreamSubscription<List<SubstitutionParticipant>>? _participantsSubscription;
  StreamSubscription<List<VacationPeriod>>? _vacationPeriodsSubscription;

  List<VacationPeriod> _vacationPeriods = const <VacationPeriod>[];
  Object? _vacationPeriodsError;

  Timer? _dayRolloverTimer;

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
        _isWorkDisplayNameActionInProgress ||
        _isRotationEditApplying;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);

    _participantsService = SubstitutionParticipantsService.firebase();
    _userCache = SubstitutionUserCache.firebase();
    _callService = createSubstitutionCallService();
    _callReconciliationService = createSubstitutionCallReconciliationService();
    _participantActionsService = createSubstitutionParticipantActionsService();
    _rotationEditService = createSubstitutionRotationEditService();
    _workDisplayNameService = createSubstitutionWorkDisplayNameService();
    _workProfileService = createSubstitutionWorkProfileService();
    _statisticsService = createSubstitutionStatisticsService();
    _uiPreferences = SubstitutionUiPreferences();
    _vacationPeriodService = VacationPeriodService.firebase();

    unawaited(_loadAccessRole());
    unawaited(_loadUiPreferences());
    _watchParticipants();
    _watchVacationPeriods();
    _scheduleDayRollover();
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
    if (_isRotationEditing) {
      _cancelRotationEditing();
      return;
    }
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
    WidgetsBinding.instance.removeObserver(this);

    _dayRolloverTimer?.cancel();

    final vacationPeriodsSubscription = _vacationPeriodsSubscription;

    if (vacationPeriodsSubscription != null) {
      unawaited(vacationPeriodsSubscription.cancel());
    }

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
      if (role.canManageSubstitution) {
        unawaited(_reconcileExpiredPendingCalls());
      }
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

  Future<void> _reconcileExpiredPendingCalls() async {
    try {
      final finalizedCount = await _callReconciliationService
          .reconcileExpiredPendingCalls(now: DateTime.now());

      if (!mounted || finalizedCount == 0) {
        return;
      }

      _retryStatistics();
    } catch (_) {
      // Recovery не должен мешать открытию Подсменки.
      // Следующий менеджер или следующее открытие
      // повторит попытку безопасной финализации.
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
        await _ensureStatisticsLoaded();
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
      unawaited(_ensureStatisticsLoaded());
    }
  }

  Future<void> _saveShowStatistics(bool value) async {
    try {
      await _uiPreferences.saveShowStatistics(value);
    } catch (_) {
      // Пока статистика является только UI-настройкой.
    }
  }

  Future<void> _ensureStatisticsLoaded() async {
    final year = DateTime.now().year;

    if (!_showStatistics ||
        _isStatisticsLoading ||
        (_statisticsLoaded && _statisticsYear == year)) {
      return;
    }

    setState(() {
      _isStatisticsLoading = true;
      _statisticsError = null;
    });

    try {
      final statistics = await _statisticsService.load(year: year);

      if (!mounted) {
        return;
      }

      setState(() {
        _statistics = statistics;
        _statisticsLoaded = true;
        _statisticsYear = year;
        _statisticsError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statisticsError = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStatisticsLoading = false;
        });
      }
    }
  }

  void _retryStatistics() {
    if (!_showStatistics || _isStatisticsLoading) {
      return;
    }

    setState(() {
      _statistics = null;
      _statisticsLoaded = false;
      _statisticsYear = null;
      _statisticsError = null;
    });

    unawaited(_ensureStatisticsLoaded());
  }

  int? _currentMonthStatisticsCountFor(String userId) {
    if (!_showStatistics || !_statisticsLoaded || _statisticsError != null) {
      return null;
    }

    final now = DateTime.now();

    if (_statisticsYear != now.year) {
      return null;
    }

    return _statistics?.callsForMonth(month: now.month, userId: userId) ?? 0;
  }

  List<SubstitutionShiftKind> _currentMonthStatisticsShiftsFor(String userId) {
    if (!_showStatistics || !_statisticsLoaded || _statisticsError != null) {
      return const <SubstitutionShiftKind>[];
    }

    final now = DateTime.now();

    if (_statisticsYear != now.year) {
      return const <SubstitutionShiftKind>[];
    }

    return _statistics?.shiftsForMonth(month: now.month, userId: userId) ??
        const <SubstitutionShiftKind>[];
  }

  int? _currentYearStatisticsCountFor(String userId) {
    if (!_showStatistics || !_statisticsLoaded || _statisticsError != null) {
      return null;
    }

    final now = DateTime.now();

    if (_statisticsYear != now.year) {
      return null;
    }

    return _statistics?.callsForYear(userId) ?? 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }

    setState(() {});

    _scheduleDayRollover();
  }

  void _scheduleDayRollover() {
    _dayRolloverTimer?.cancel();

    final now = DateTime.now();

    final nextDay = DateTime(now.year, now.month, now.day + 1);

    _dayRolloverTimer = Timer(
      nextDay.difference(now) + const Duration(milliseconds: 100),
      () {
        if (!mounted) {
          return;
        }

        setState(() {});

        _scheduleDayRollover();
      },
    );
  }

  void _watchVacationPeriods() {
    final subscription = _vacationPeriodsSubscription;

    _vacationPeriodsSubscription = null;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    _vacationPeriodsSubscription = _vacationPeriodService.watchAll().listen(
      (periods) {
        if (!mounted) {
          return;
        }

        setState(() {
          _vacationPeriods = periods;
          _vacationPeriodsError = null;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) {
          return;
        }

        setState(() {
          _vacationPeriodsError = error;
        });
      },
    );
  }

  void _retryVacationPeriods() {
    setState(() {
      _vacationPeriodsError = null;
    });

    _watchVacationPeriods();
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
        participants
            .where((participant) => !participant.isRemoved)
            .map((participant) => participant.userId),
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
                .where((participant) => !participant.isRemoved)
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

  Future<void> _beginRotationEditing() async {
    if (_isActionInProgress ||
        _isRotationEditing ||
        !_accessRole.canManageSubstitution) {
      return;
    }

    setState(() {
      _isRotationActionInProgress = true;
    });

    try {
      final baseline = await _rotationEditService.beginEditing();

      if (!mounted) {
        return;
      }

      final draft = SubstitutionRotationDraft.fromParticipants(_participants);

      setState(() {
        _rotationDraft = draft;
        _rotationEditBaseline = baseline;
        _isParticipantOverlayOpen = false;
        _selectedParticipantId = null;
      });

      _goToParticipantList();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть режим редактирования списка'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRotationActionInProgress = false;
        });
      }
    }
  }

  void _cancelRotationEditing() {
    if (!_isRotationEditing || _isRotationEditApplying) {
      return;
    }

    setState(() {
      _rotationDraft = null;
      _rotationEditBaseline = null;
    });
  }

  void _moveRotationParticipantUp(SubstitutionParticipant participant) {
    final draft = _rotationDraft;
    if (_isRotationEditApplying) {
      return;
    }

    if (draft == null || !draft.canMoveActiveUp(participant.userId)) {
      return;
    }

    setState(() {
      _rotationDraft = draft.moveActiveUp(participant.userId);
    });
  }

  void _moveRotationParticipantDown(SubstitutionParticipant participant) {
    final draft = _rotationDraft;
    if (_isRotationEditApplying) {
      return;
    }

    if (draft == null || !draft.canMoveActiveDown(participant.userId)) {
      return;
    }

    setState(() {
      _rotationDraft = draft.moveActiveDown(participant.userId);
    });
  }

  Future<void> _applyRotationEditing() async {
    final draft = _rotationDraft;
    final baseline = _rotationEditBaseline;

    if (draft == null ||
        baseline == null ||
        _isRotationEditApplying ||
        !_accessRole.canManageSubstitution) {
      return;
    }

    setState(() {
      _isRotationEditApplying = true;
    });

    try {
      final result = await _rotationEditService.apply(
        draft: draft,
        baseline: baseline,
      );

      if (!mounted) {
        return;
      }

      switch (result) {
        case SubstitutionRotationEditApplyResult.noChanges:
          setState(() {
            _rotationDraft = null;
            _rotationEditBaseline = null;
          });

        case SubstitutionRotationEditApplyResult.applied:
          setState(() {
            _rotationDraft = null;
            _rotationEditBaseline = null;
          });

        case SubstitutionRotationEditApplyResult.conflict:
          setState(() {
            _rotationDraft = null;
            _rotationEditBaseline = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Список изменился. Откройте режим редактирования заново.',
              ),
            ),
          );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось применить изменения списка')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRotationEditApplying = false;
        });
      }
    }
  }

  Widget _buildRotationEditActions() {
    final hasChanges = _rotationDraft?.hasChanges ?? false;

    final canApply = hasChanges && !_isRotationEditApplying;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isRotationEditApplying
                      ? null
                      : _cancelRotationEditing,
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: canApply
                      ? () {
                          unawaited(_applyRotationEditing());
                        }
                      : null,
                  child: Text(
                    _isRotationEditApplying ? 'Применение...' : 'Применить',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          onEditParticipants: canManageSubstitution
              ? () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_beginRotationEditing());
                }
              : null,
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

  Future<void> _editParticipantWorkProfile(
    SubstitutionParticipant participant,
    AppUser user,
  ) async {
    if (_isActionInProgress || !_accessRole.canManageSubstitution) {
      return;
    }

    var editedName = user.workDisplayName.trim();
    var editedCrew = user.assignedCrew;

    final result = await showDialog<_SubstitutionWorkProfileEditResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Рабочий профиль'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: editedName,
                      autofocus: true,
                      maxLength: SubstitutionWorkProfileService
                          .maxWorkDisplayNameLength,
                      decoration: InputDecoration(
                        labelText: 'Имя в подсменке',
                        hintText: user.name.trim().isEmpty
                            ? null
                            : user.name.trim(),
                        helperText:
                            'Пустое поле вернёт обычное имя пользователя',
                      ),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (value) {
                        editedName = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ShiftCrew>(
                      initialValue: editedCrew,
                      decoration: const InputDecoration(
                        labelText: 'Звено',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Не выбрано'),
                      items: ShiftCrew.values
                          .map(
                            (crew) => DropdownMenuItem<ShiftCrew>(
                              value: crew,
                              child: Text(crew.displayName),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (crew) {
                        setDialogState(() {
                          editedCrew = crew;
                        });
                      },
                    ),
                  ],
                ),
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
                    Navigator.of(dialogContext).pop(
                      _SubstitutionWorkProfileEditResult(
                        workDisplayName: editedName,
                        crew: editedCrew,
                      ),
                    );
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final normalizedName = result.workDisplayName.trim();
    final selectedCrew = result.crew;

    final nameChanged = normalizedName != user.workDisplayName.trim();
    final crewChanged =
        selectedCrew != null && selectedCrew != user.assignedCrew;

    if (!nameChanged && !crewChanged) {
      return;
    }

    setState(() {
      _isWorkDisplayNameActionInProgress = true;
    });

    try {
      if (selectedCrew == null) {
        await _workDisplayNameService.updateWorkDisplayName(
          userId: participant.userId,
          workDisplayName: normalizedName,
        );
      } else {
        await _workProfileService.updateWorkProfile(
          userId: participant.userId,
          workDisplayName: normalizedName,
          crew: selectedCrew,
        );
      }

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
        const SnackBar(content: Text('Не удалось изменить рабочий профиль')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorkDisplayNameActionInProgress = false;
        });
      }
    }
  }

  String _callIneligibilityReasonText(
    SubstitutionCallIneligibilityReason reason,
  ) {
    return switch (reason) {
      SubstitutionCallIneligibilityReason.missingCrew =>
        'Недоступно: не указано звено',
      SubstitutionCallIneligibilityReason.vacation => 'Недоступно: отпуск',
      SubstitutionCallIneligibilityReason.workShift =>
        'Недоступно: рабочая смена',
    };
  }

  String? _callIneligibilityText(SubstitutionCallEligibility eligibility) {
    final reason = eligibility.reason;

    if (reason == null) {
      return null;
    }

    return _callIneligibilityReasonText(reason);
  }

  Future<void> _confirmCallParticipant(
    SubstitutionParticipant participant,
  ) async {
    if (!_accessRole.canManageSubstitution ||
        _isActionInProgress ||
        !participant.isActive) {
      return;
    }

    var user = _userCache.userById(participant.userId);

    if (user == null) {
      try {
        await _userCache.refresh(participant.userId);
      } catch (_) {
        // Ниже покажем единое сообщение.
      }

      if (!mounted) {
        return;
      }

      user = _userCache.userById(participant.userId);
    }

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось проверить доступность участника'),
        ),
      );
      return;
    }

    if (_vacationPeriodsError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось проверить данные отпусков')),
      );
      return;
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final todayNightShift = SubstitutionShift(
      year: today.year,
      month: today.month,
      day: today.day,
      kind: SubstitutionShiftKind.night,
    );

    final tomorrowDayShift = SubstitutionShift(
      year: tomorrow.year,
      month: tomorrow.month,
      day: tomorrow.day,
      kind: SubstitutionShiftKind.day,
    );

    final todayNightEligibility = _callEligibilityResolver.resolve(
      userId: participant.userId,
      crew: user.assignedCrew,
      shift: todayNightShift,
      vacationPeriods: _vacationPeriods,
    );

    final tomorrowDayEligibility = _callEligibilityResolver.resolve(
      userId: participant.userId,
      crew: user.assignedCrew,
      shift: tomorrowDayShift,
      vacationPeriods: _vacationPeriods,
    );

    final todayNightReason = _callIneligibilityText(todayNightEligibility);
    final tomorrowDayReason = _callIneligibilityText(tomorrowDayEligibility);

    final selectedShift = await showDialog<SubstitutionShift>(
      context: context,
      builder: (dialogContext) {
        const buttonHeight = 48.0;

        final reasonStyle = Theme.of(dialogContext).textTheme.bodySmall
            ?.copyWith(color: Theme.of(dialogContext).colorScheme.error);

        return AlertDialog(
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: FilledButton(
                  onPressed: todayNightEligibility.isEligible
                      ? () {
                          Navigator.of(dialogContext).pop(todayNightShift);
                        }
                      : null,
                  child: const Text('Сегодня в ночь'),
                ),
              ),
              if (todayNightReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  todayNightReason,
                  textAlign: TextAlign.center,
                  style: reasonStyle,
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: FilledButton(
                  onPressed: tomorrowDayEligibility.isEligible
                      ? () {
                          Navigator.of(dialogContext).pop(tomorrowDayShift);
                        }
                      : null,
                  child: const Text('Завтра в день'),
                ),
              ),
              if (tomorrowDayReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  tomorrowDayReason,
                  textAlign: TextAlign.center,
                  style: reasonStyle,
                ),
              ],
              const SizedBox(height: 18),
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

      Timer(const Duration(seconds: 3), () {
        if (!mounted) {
          return;
        }

        messenger.hideCurrentSnackBar();

        unawaited(_finalizePendingCallAfterUndoWindow(receipt));
      });
    } on SubstitutionCallUnavailableException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_callIneligibilityReasonText(error.reason))),
      );
    } on SubstitutionShiftAlreadyCalledException {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$displayName уже вызван на эту смену')),
      );
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

  Future<void> _finalizePendingCallAfterUndoWindow(
    SubstitutionCallReceipt receipt,
  ) async {
    try {
      final finalized = await _callReconciliationService.finalizePendingCall(
        callId: receipt.callId,
      );

      if (!mounted || !finalized) {
        return;
      }

      _retryStatistics();
    } catch (_) {
      // Если финализация не удалась, pendingCall остаётся.
      // Recovery при следующем открытии Подсменки
      // безопасно повторит попытку.
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

  Future<void> _openParticipantVacationPeriods(
    SubstitutionParticipant participant,
  ) async {
    if (_isActionInProgress || !_accessRole.canManageSubstitution) {
      return;
    }

    final participantPeriods = _vacationPeriods
        .where((period) => period.userId == participant.userId)
        .toList(growable: false);

    final now = DateTime.now();

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return VacationPeriodsScreen(
            calendarYear: now.year,
            userId: participant.userId,
            initialPeriods: participantPeriods,
            service: _vacationPeriodService,
            onPeriodsChanged: (updatedPeriods) {
              if (!mounted) {
                return;
              }

              setState(() {
                _vacationPeriods = <VacationPeriod>[
                  ..._vacationPeriods.where(
                    (period) => period.userId != participant.userId,
                  ),
                  ...updatedPeriods,
                ];

                _vacationPeriodsError = null;
              });
            },
          );
        },
      ),
    );
    if (mounted) {
      _watchVacationPeriods();
    }
  }

  Future<void> _updateParticipantStatus(
    SubstitutionParticipant participant,
    SubstitutionParticipantStatus status,
  ) async {
    final isOwnSickReturn =
        participant.userId == _currentUserId &&
        participant.status == SubstitutionParticipantStatus.sick &&
        status == SubstitutionParticipantStatus.active;

    if (_isActionInProgress ||
        (!_accessRole.canManageSubstitution && !isOwnSickReturn) ||
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

  List<SubstitutionParticipant> _applyEffectiveStatuses(
    Iterable<SubstitutionParticipant> participants,
  ) {
    final now = DateTime.now();

    return participants
        .map((participant) {
          final status = _effectiveStatusResolver.resolve(
            participant: participant,
            vacationPeriods: _vacationPeriods,
            date: now,
          );

          if (status == participant.status) {
            return participant;
          }

          return participant.withStatus(status);
        })
        .toList(growable: false);
  }

  bool _isOnCalendarVacation(String userId) {
    final normalizedUserId = userId.trim();
    final now = DateTime.now();

    return _vacationPeriods.any(
      (period) => period.userId == normalizedUserId && period.contains(now),
    );
  }

  String? _currentVacationTextFor(String userId) {
    final normalizedUserId = userId.trim();
    final now = DateTime.now();

    VacationPeriod? currentPeriod;

    for (final period in _vacationPeriods) {
      if (period.userId != normalizedUserId || !period.contains(now)) {
        continue;
      }

      if (currentPeriod == null ||
          period.startDateOnly.isBefore(currentPeriod.startDateOnly)) {
        currentPeriod = period;
      }
    }

    if (currentPeriod == null) {
      return null;
    }

    return '${_formatShortDate(currentPeriod.startDateOnly)}–'
        '${_formatShortDate(currentPeriod.endDateOnly)}';
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month';
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

  SubstitutionParticipant? _participantById(
    String? userId, {
    Iterable<SubstitutionParticipant>? participants,
  }) {
    if (userId == null || userId.isEmpty) {
      return null;
    }

    final source = participants ?? _participants;

    for (final participant in source) {
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
    final sourceParticipants = _rotationDraft?.participants ?? _participants;

    final displayedParticipants = _applyEffectiveStatuses(sourceParticipants);

    final activeParticipants = displayedParticipants
        .where((participant) => participant.isActive)
        .toList(growable: false);

    final vacationParticipants = displayedParticipants
        .where((participant) => participant.isOnVacation)
        .toList(growable: false);

    final sickParticipants = displayedParticipants
        .where((participant) => participant.isSick)
        .toList(growable: false);

    final usersById = _userCache.usersById;

    final canManageSubstitution =
        !_isAccessRoleLoading && _accessRole.canManageSubstitution;

    final selectedParticipant = _participantById(
      _selectedParticipantId,
      participants: displayedParticipants,
    );

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
      canPop:
          !_isRotationEditing &&
          !_isParticipantOverlayOpen &&
          _currentTabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (_isRotationEditing) {
          _cancelRotationEditing();
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
              title: Text(
                _isRotationEditing ? 'Редактирование списка' : 'Список',
              ),
              actions: [
                IconButton(
                  tooltip: 'Настройки списка',
                  onPressed: _isActionInProgress || _isRotationEditing
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
            bottomNavigationBar: _isRotationEditing
                ? _buildRotationEditActions()
                : null,
          ),
          SubstitutionParticipantOverlay(
            isOpen: _isParticipantOverlayOpen,
            participant: selectedParticipant,
            user: selectedUser,
            queuePosition: selectedQueuePosition,
            monthlyCallCount: selectedParticipant != null
                ? _currentMonthStatisticsCountFor(selectedParticipant.userId)
                : null,
            statisticsMonth:
                selectedParticipant != null &&
                    _currentMonthStatisticsCountFor(
                          selectedParticipant.userId,
                        ) !=
                        null
                ? DateTime.now().month
                : null,
            monthShifts: selectedParticipant != null
                ? _currentMonthStatisticsShiftsFor(selectedParticipant.userId)
                : const <SubstitutionShiftKind>[],
            yearCallCount: selectedParticipant != null
                ? _currentYearStatisticsCountFor(selectedParticipant.userId)
                : null,
            showAssignedCrew: canManageSubstitution,
            onClose: _closeParticipantCard,
            onEditName:
                canManageSubstitution &&
                    selectedParticipant != null &&
                    selectedUser != null &&
                    !_isActionInProgress
                ? () {
                    unawaited(
                      _editParticipantWorkProfile(
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
                    (selectedParticipant.isActive ||
                        selectedParticipant.isOnVacation) &&
                    !_isActionInProgress
                ? () {
                    unawaited(
                      _openParticipantVacationPeriods(selectedParticipant),
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
                selectedParticipant != null &&
                    !_isActionInProgress &&
                    ((canManageSubstitution &&
                            !selectedParticipant.isActive &&
                            !_isOnCalendarVacation(
                              selectedParticipant.userId,
                            )) ||
                        (selectedParticipant.userId == _currentUserId &&
                            selectedParticipant.isSick))
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
        if (_vacationPeriodsError != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Не удалось загрузить данные отпусков'),
              trailing: TextButton(
                onPressed: _retryVacationPeriods,
                child: const Text('Повторить'),
              ),
            ),
          ),
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
        if (_showStatistics && !_isRotationEditing && _isStatisticsLoading)
          const LinearProgressIndicator(minHeight: 2),

        if (_showStatistics && !_isRotationEditing && _statisticsError != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Не удалось загрузить статистику'),
              trailing: TextButton(
                onPressed: _retryStatistics,
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
                emptyText: '...',
                showQueueNumber: true,
                queueDisplayMode: _queueDisplayMode,
                showStatistics: _showStatistics && !_isRotationEditing,
                statisticsCountFor: _currentMonthStatisticsCountFor,
                onCall:
                    !_isRotationEditing &&
                        canManageSubstitution &&
                        !_isActionInProgress
                    ? (participant) {
                        unawaited(_confirmCallParticipant(participant));
                      }
                    : null,
                onOpenCard: _isRotationEditing ? null : _openParticipantCard,
                showRotationControls: _isRotationEditing,
                canMoveUp: (participant) {
                  return _rotationDraft?.canMoveActiveUp(participant.userId) ??
                      false;
                },
                canMoveDown: (participant) {
                  return _rotationDraft?.canMoveActiveDown(
                        participant.userId,
                      ) ??
                      false;
                },
                onMoveUp: _moveRotationParticipantUp,
                onMoveDown: _moveRotationParticipantDown,
              ),
              _ParticipantListTab(
                participants: vacationParticipants,
                usersById: usersById,
                emptyText: 'В отпуске никого нет',
                showQueueNumber: false,
                queueDisplayMode: _queueDisplayMode,
                showStatistics: false,
                statisticsCountFor: _currentMonthStatisticsCountFor,
                secondaryTextFor: _currentVacationTextFor,
                onTap:
                    !_isRotationEditing &&
                        canManageSubstitution &&
                        !_isActionInProgress
                    ? (participant) {
                        unawaited(_openParticipantVacationPeriods(participant));
                      }
                    : null,
                onOpenCard: _isRotationEditing ? null : _openParticipantCard,
              ),
              _ParticipantListTab(
                participants: sickParticipants,
                usersById: usersById,
                emptyText: 'На больничном никого нет',
                showQueueNumber: false,
                queueDisplayMode: _queueDisplayMode,
                showStatistics: false,
                statisticsCountFor: _currentMonthStatisticsCountFor,
                onOpenCard: _isRotationEditing ? null : _openParticipantCard,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantListTab extends StatefulWidget {
  const _ParticipantListTab({
    required this.participants,
    required this.usersById,
    required this.emptyText,
    required this.showQueueNumber,
    required this.queueDisplayMode,
    required this.showStatistics,
    required this.statisticsCountFor,
    this.secondaryTextFor,
    this.onOpenCard,
    this.onCall,
    this.showRotationControls = false,
    this.canMoveUp,
    this.canMoveDown,
    this.onMoveUp,
    this.onMoveDown,
    this.onTap,
  });

  final List<SubstitutionParticipant> participants;
  final Map<String, AppUser> usersById;

  final String emptyText;
  final bool showQueueNumber;
  final SubstitutionQueueDisplayMode queueDisplayMode;
  final bool showStatistics;
  final int? Function(String userId) statisticsCountFor;
  final String? Function(String userId)? secondaryTextFor;

  final ValueChanged<SubstitutionParticipant>? onOpenCard;
  final ValueChanged<SubstitutionParticipant>? onCall;

  final bool showRotationControls;

  final bool Function(SubstitutionParticipant participant)? canMoveUp;

  final bool Function(SubstitutionParticipant participant)? canMoveDown;

  final ValueChanged<SubstitutionParticipant>? onMoveUp;
  final ValueChanged<SubstitutionParticipant>? onMoveDown;
  final ValueChanged<SubstitutionParticipant>? onTap;

  @override
  State<_ParticipantListTab> createState() => _ParticipantListTabState();
}

class _ParticipantListTabState extends State<_ParticipantListTab> {
  final ScrollController _scrollController = ScrollController();

  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  double _appliedScrollReserve = 0;
  bool _scrollReserveSyncScheduled = false;
  bool _isMoveInProgress = false;

  @override
  void didUpdateWidget(covariant _ParticipantListTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentUserIds = widget.participants
        .map((participant) => participant.userId)
        .toSet();

    _rowKeys.removeWhere((userId, _) => !currentUserIds.contains(userId));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _syncScrollReserve(double nextReserve) {
    if (_scrollReserveSyncScheduled ||
        (nextReserve - _appliedScrollReserve).abs() < 0.5) {
      return;
    }

    _scrollReserveSyncScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollReserveSyncScheduled = false;

      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final delta = nextReserve - _appliedScrollReserve;

      if (delta.abs() < 0.5) {
        return;
      }

      final position = _scrollController.position;

      final targetOffset = (_scrollController.offset + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

      _appliedScrollReserve = nextReserve;

      if ((targetOffset - _scrollController.offset).abs() < 0.5) {
        return;
      }

      _scrollController.jumpTo(targetOffset);
      _isMoveInProgress = false;
    });
  }

  void _moveKeepingScreenPosition({
    required SubstitutionParticipant participant,
    required ValueChanged<SubstitutionParticipant> onMove,
  }) {
    if (_isMoveInProgress) {
      return;
    }

    _isMoveInProgress = true;

    final rowKey = _rowKeys[participant.userId];
    final rowContext = rowKey?.currentContext;
    final renderObject = rowContext?.findRenderObject();

    final beforeDy = renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero).dy
        : null;

    onMove(participant);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        if (beforeDy == null) {
          return;
        }

        final updatedContext = _rowKeys[participant.userId]?.currentContext;

        final updatedRenderObject = updatedContext?.findRenderObject();

        if (updatedRenderObject is! RenderBox) {
          return;
        }

        final afterDy = updatedRenderObject.localToGlobal(Offset.zero).dy;

        final screenDelta = afterDy - beforeDy;

        if (screenDelta.abs() < 0.5) {
          return;
        }

        final position = _scrollController.position;

        final targetOffset = (_scrollController.offset + screenDelta)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();

        if ((targetOffset - _scrollController.offset).abs() < 0.5) {
          return;
        }

        _scrollController.jumpTo(targetOffset);
      } finally {
        _isMoveInProgress = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.participants.isEmpty) {
      return _EmptySubstitutionTab(text: widget.emptyText);
    }

    final bottomSystemInset = MediaQuery.viewPaddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollReserve = widget.showRotationControls
            ? constraints.maxHeight
            : 0.0;

        _syncScrollReserve(scrollReserve);

        return ListView.separated(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            0,
            8 + scrollReserve,
            0,
            8 + bottomSystemInset + scrollReserve,
          ),
          itemCount: widget.participants.length,
          separatorBuilder: (context, index) {
            return const Divider(height: 1, indent: 72);
          },
          itemBuilder: (context, index) {
            final participant = widget.participants[index];

            final user = widget.usersById[participant.userId];

            final rowKey = _rowKeys.putIfAbsent(
              participant.userId,
              () => GlobalKey(),
            );

            return KeyedSubtree(
              key: rowKey,
              child: SubstitutionParticipantRow(
                participant: participant,
                user: user,
                queuePosition: widget.showQueueNumber ? index + 1 : null,
                queueDisplayMode: widget.queueDisplayMode,
                secondaryText: widget.secondaryTextFor?.call(
                  participant.userId,
                ),
                statisticsCount: widget.showStatistics
                    ? widget.statisticsCountFor(participant.userId)
                    : null,
                onTap: widget.onTap == null
                    ? null
                    : () {
                        widget.onTap!(participant);
                      },
                onCall: widget.onCall == null
                    ? null
                    : () {
                        widget.onCall!(participant);
                      },
                onOpenCard: widget.onOpenCard == null
                    ? null
                    : () {
                        widget.onOpenCard!(participant);
                      },
                showRotationControls: widget.showRotationControls,
                onMoveUp:
                    widget.showRotationControls &&
                        (widget.canMoveUp?.call(participant) ?? false) &&
                        widget.onMoveUp != null
                    ? () {
                        _moveKeepingScreenPosition(
                          participant: participant,
                          onMove: widget.onMoveUp!,
                        );
                      }
                    : null,
                onMoveDown:
                    widget.showRotationControls &&
                        (widget.canMoveDown?.call(participant) ?? false) &&
                        widget.onMoveDown != null
                    ? () {
                        _moveKeepingScreenPosition(
                          participant: participant,
                          onMove: widget.onMoveDown!,
                        );
                      }
                    : null,
              ),
            );
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
