import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/models/shift_cycle.dart';
import '../domain/models/vacation_period.dart';
import '../domain/models/substitution_shift.dart';
import '../services/spaces/calendar/shift_schedule_calculator.dart';
import '../services/spaces/calendar/vacation_period_service.dart';
import 'shift_calendar_settings_screen.dart';
import 'shift_alarm_settings_screen.dart';
import 'vacation_periods_screen.dart';
import '../domain/models/calendar_entry.dart';
import 'calendar_entry_editor_screen.dart';
import '../services/spaces/calendar/calendar_entry_local_store.dart';
import '../services/spaces/calendar/calendar_entry_service.dart';
import '../services/spaces/calendar/calendar_entry_day_markers.dart';
import '../domain/models/calendar_additional_shift_event.dart';
import '../services/spaces/calendar/calendar_additional_shift_service.dart';
import '../services/work_schedule/user_assigned_crew_reader.dart';
import 'assigned_crew_setup_screen.dart';
import '../services/spaces/calendar/shift_alarm_scheduling_service.dart';
import '../services/spaces/calendar/shift_month_hours_calculator.dart';
import '../domain/models/shift_calendar_theme.dart';
import '../services/spaces/calendar/shift_calendar_theme_preferences.dart';
import 'shift_calendar_theme_screen.dart';

enum ShiftCalendarViewMode { full, compact }

enum _CalendarMenuAction { crew, vacations, alarms, themes }

class ShiftCalendarScreen extends StatefulWidget {
  const ShiftCalendarScreen({super.key});

  @override
  State<ShiftCalendarScreen> createState() => _ShiftCalendarScreenState();
}

class _ShiftCalendarScreenState extends State<ShiftCalendarScreen> {
  static const _initialPage = 1200;

  final ShiftScheduleCalculator _calculator = const ShiftScheduleCalculator();
  final ShiftMonthHoursCalculator _monthHoursCalculator =
      const ShiftMonthHoursCalculator();
  final ShiftCalendarThemePreferences _calendarThemePreferences =
      ShiftCalendarThemePreferences();

  ShiftCalendarThemeState _calendarThemeState = const ShiftCalendarThemeState(
    mode: ShiftCalendarThemeMode.light,
    customSlot: ShiftCalendarCustomThemeSlot.first,
    customFirst: ShiftCalendarThemePalette.customFirstDefault,
    customSecond: ShiftCalendarThemePalette.customSecondDefault,
  );

  final CalendarEntryService _calendarEntryService = CalendarEntryService(
    const CalendarEntryLocalStore(),
  );

  List<CalendarEntry> _calendarEntries = const <CalendarEntry>[];

  late PageController _pageController;
  late final DateTime _baseMonth;

  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  late DateTime _compactFocusedDate;

  bool _hasSelectedDate = false;
  int _compactStripRevision = 0;

  ShiftCalendarViewMode _viewMode = ShiftCalendarViewMode.full;

  // Пока первая версия открывается для 4 звена.
  late final UserAssignedCrewReader _assignedCrewReader;

  StreamSubscription<ShiftCrew?>? _assignedCrewSubscription;

  ShiftCrew? _assignedCrew;
  ShiftCrew? _previewCrew;

  bool _isAssignedCrewLoaded = false;
  bool _assignedCrewLoadFailed = false;

  late final VacationPeriodService _vacationPeriodService;
  late final CalendarAdditionalShiftService _additionalShiftService;
  late final ShiftAlarmSchedulingService _shiftAlarmSchedulingService;

  StreamSubscription<List<VacationPeriod>>? _vacationPeriodsSubscription;
  StreamSubscription<List<CalendarAdditionalShiftEvent>>?
  _additionalShiftSubscription;

  List<VacationPeriod> _vacationPeriods = const <VacationPeriod>[];
  List<CalendarAdditionalShiftEvent> _additionalShiftEvents =
      const <CalendarAdditionalShiftEvent>[];

  Future<void> _shiftAlarmReconcileQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _baseMonth = DateTime(now.year, now.month);
    _visibleMonth = _baseMonth;
    _selectedDate = DateTime(now.year, now.month, now.day);
    _compactFocusedDate = _selectedDate;

    _pageController = PageController(initialPage: _initialPage);
    _vacationPeriodService = VacationPeriodService.firebase();
    _additionalShiftService = CalendarAdditionalShiftService.firebase();
    _assignedCrewReader = UserAssignedCrewReader.firebase();
    _shiftAlarmSchedulingService = ShiftAlarmSchedulingService();

    _watchAssignedCrew();
    _watchVacationPeriods();
    _watchAdditionalShifts();

    unawaited(_loadCalendarTheme());
    unawaited(_loadCalendarEntries());
    unawaited(_reconcileCalendarReminders());
  }

  Future<void> _openCalendarEntryEditor(CalendarEntryKind kind) async {
    if (!_hasSelectedDate) {
      return;
    }

    final result = await Navigator.of(context).push<CalendarEntryEditorResult>(
      MaterialPageRoute(
        builder: (context) {
          return CalendarEntryEditorScreen(
            kind: kind,
            date: _selectedDate,
            palette: _calendarThemeState.activePalette,
          );
        },
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final userId = _currentUserId;

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить пользователя')),
      );
      return;
    }

    var reminderMinutes = result.reminderMinutes;

    if (reminderMinutes != null) {
      final permissionGranted = await _calendarEntryService
          .ensureReminderPermission();

      if (!mounted) {
        return;
      }

      if (!permissionGranted) {
        reminderMinutes = null;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Разрешение на точные напоминания не выдано. '
              'Запись сохранена без будильника.',
            ),
          ),
        );
      }
    }

    try {
      await _calendarEntryService.create(
        userId: userId,
        kind: result.kind,
        date: result.date,
        title: result.title,
        description: result.description,
        scheduledMinutes: result.scheduledMinutes,
        reminderMinutes: reminderMinutes,
        priority: result.priority,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить запись')),
      );
    }
  }

  Future<void> _reconcileCalendarReminders() async {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      return;
    }

    try {
      await _calendarEntryService.reconcileReminders(userId: userId);
    } catch (_) {
      // Ошибка локального reminder не должна ломать сам календарь.
    }
  }

  Future<void> _loadCalendarEntries() async {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _calendarEntries = const <CalendarEntry>[];
      });
      return;
    }

    try {
      final entries = await _calendarEntryService.loadForUser(userId: userId);

      if (!mounted) {
        return;
      }

      setState(() {
        _calendarEntries = entries;
      });
    } catch (_) {
      // Личные локальные записи не должны ломать календарь.
    }
  }

  CalendarEntryDayMarkers _entryMarkersForDate(DateTime date) {
    final entries = _calendarEntries.where((entry) => entry.occursOn(date));

    return CalendarEntryDayMarkers.fromEntries(entries);
  }

  void _setViewMode(ShiftCalendarViewMode viewMode) {
    if (_viewMode == viewMode) {
      return;
    }

    setState(() {
      _viewMode = viewMode;
    });
  }

  void _openDateInCompact(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    setState(() {
      _selectedDate = normalizedDate;
      _compactFocusedDate = normalizedDate;
      _hasSelectedDate = true;
      _viewMode = ShiftCalendarViewMode.compact;
      _compactStripRevision++;
    });
  }

  Future<void> _openAssignedCrewSetup() async {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      return;
    }

    final selectedCrew = await Navigator.of(context).push<ShiftCrew>(
      MaterialPageRoute<ShiftCrew>(
        builder: (_) {
          return AssignedCrewSetupScreen(userId: userId);
        },
      ),
    );

    if (!mounted || selectedCrew == null) {
      return;
    }

    setState(() {
      _assignedCrew = selectedCrew;
      _previewCrew = null;
      _assignedCrewLoadFailed = false;
      _isAssignedCrewLoaded = true;
    });
  }

  Future<void> _loadCalendarTheme() async {
    try {
      final state = await _calendarThemePreferences.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _calendarThemeState = state;
      });
    } catch (_) {
      // Ошибка локальной темы не должна мешать работе календаря.
    }
  }

  Future<void> _openCalendarThemeSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return ShiftCalendarThemeScreen(initialState: _calendarThemeState);
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadCalendarTheme();
  }

  Future<void> _openCalendarSettings() async {
    final currentCrew = _effectiveCrew;

    if (currentCrew == null) {
      return;
    }

    final crew = await Navigator.of(context).push<ShiftCrew>(
      MaterialPageRoute(
        builder: (_) => ShiftCalendarSettingsScreen(initialCrew: currentCrew),
      ),
    );

    if (!mounted || crew == null) {
      return;
    }

    setState(() {
      _previewCrew = crew == _assignedCrew ? null : crew;
    });
  }

  Future<void> _reconcileShiftAlarms() {
    final reconcile = _shiftAlarmReconcileQueue.then((_) async {
      final userId = _currentUserId;
      final crew = _assignedCrew;

      if (userId.isEmpty || crew == null) {
        return;
      }

      await _shiftAlarmSchedulingService.reconcile(
        userId: userId,
        crew: crew,
        vacationPeriods: _vacationPeriods,
      );
    });

    _shiftAlarmReconcileQueue = reconcile.catchError((Object _) {});

    return reconcile;
  }

  Future<void> _openShiftAlarms() async {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return ShiftAlarmSettingsScreen(
            userId: userId,
            onScheduleChanged: _reconcileShiftAlarms,
          );
        },
      ),
    );
  }

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  }

  ShiftCrew? get _effectiveCrew {
    return _previewCrew ?? _assignedCrew;
  }

  bool get _isPreviewingCrew {
    return _previewCrew != null;
  }

  void _watchAssignedCrew() {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      _isAssignedCrewLoaded = true;
      return;
    }

    _assignedCrewSubscription = _assignedCrewReader
        .watch(userId: userId)
        .listen(
          (crew) {
            if (!mounted) {
              return;
            }

            setState(() {
              _assignedCrew = crew;
              _assignedCrewLoadFailed = false;
              _isAssignedCrewLoaded = true;

              if (_previewCrew == crew) {
                _previewCrew = null;
              }
            });
            unawaited(_reconcileShiftAlarms());
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) {
              return;
            }

            setState(() {
              _assignedCrewLoadFailed = true;
              _isAssignedCrewLoaded = true;
            });
          },
        );
  }

  void _watchVacationPeriods() {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      return;
    }

    _vacationPeriodsSubscription = _vacationPeriodService
        .watchForUser(userId: userId)
        .listen(
          (periods) {
            if (!mounted) {
              return;
            }

            setState(() {
              _vacationPeriods = periods;
            });
            unawaited(_reconcileShiftAlarms());
          },
          onError: (Object error, StackTrace stackTrace) {
            // Ошибка Firestore не должна ломать сам календарь.
            // До deploy Vacation Rules календарь просто останется
            // без сохранённых отпусков.
          },
        );
  }

  void _watchAdditionalShifts() {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      return;
    }

    _additionalShiftSubscription = _additionalShiftService
        .watchForUser(userId: userId)
        .listen(
          (events) {
            if (!mounted) {
              return;
            }

            setState(() {
              _additionalShiftEvents = events;
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            // Ошибка Firestore не должна ломать сам календарь.
            // Календарь просто останется без дополнительных смен.
          },
        );
  }

  bool _hasAdditionalShiftForDate(DateTime date) {
    return _additionalShiftEvents.any((event) => event.occursOn(date));
  }

  List<CalendarAdditionalShiftEvent> _additionalShiftsForDate(DateTime date) {
    if (_isVacationDate(date, _vacationPeriods)) {
      return const <CalendarAdditionalShiftEvent>[];
    }

    return _additionalShiftEvents
        .where((event) => event.occursOn(date))
        .toList(growable: false);
  }

  @override
  void dispose() {
    final assignedCrewSubscription = _assignedCrewSubscription;

    if (assignedCrewSubscription != null) {
      unawaited(assignedCrewSubscription.cancel());
    }

    final vacationSubscription = _vacationPeriodsSubscription;

    if (vacationSubscription != null) {
      unawaited(vacationSubscription.cancel());
    }

    final additionalShiftSubscription = _additionalShiftSubscription;

    if (additionalShiftSubscription != null) {
      unawaited(additionalShiftSubscription.cancel());
    }

    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    final monthOffset = page - _initialPage;
    final month = DateTime(_baseMonth.year, _baseMonth.month + monthOffset);

    setState(() {
      _visibleMonth = month;
      _hasSelectedDate = false;
    });
  }

  int _pageForMonth(DateTime month) {
    final monthOffset =
        (month.year - _baseMonth.year) * 12 + month.month - _baseMonth.month;

    return _initialPage + monthOffset;
  }

  void _goToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayMonth = DateTime(today.year, today.month);

    if (_viewMode == ShiftCalendarViewMode.compact) {
      setState(() {
        _selectedDate = today;
        _compactFocusedDate = today;
        _hasSelectedDate = true;
        _compactStripRevision++;
      });

      return;
    }

    final targetPage = _pageForMonth(todayMonth);

    if (_pageController.hasClients) {
      setState(() {
        _visibleMonth = todayMonth;
        _selectedDate = today;
        _compactFocusedDate = today;
        _hasSelectedDate = false;
      });

      unawaited(
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );

      return;
    }

    _pageController.dispose();
    _pageController = PageController(initialPage: targetPage);

    setState(() {
      _visibleMonth = todayMonth;
      _selectedDate = today;
      _compactFocusedDate = today;
      _hasSelectedDate = false;
      _compactStripRevision++;
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    // Свайп вниз: compact -> full.
    if (velocity > 250) {
      if (_viewMode == ShiftCalendarViewMode.compact) {
        _setViewMode(ShiftCalendarViewMode.full);
      }

      return;
    }

    // Свайп вверх: full -> compact.
    if (velocity < -250) {
      if (_viewMode == ShiftCalendarViewMode.full) {
        final now = DateTime.now();

        final isCurrentMonth =
            _visibleMonth.year == now.year && _visibleMonth.month == now.month;

        if (isCurrentMonth) {
          _openDateInCompact(DateTime(now.year, now.month, now.day));
          return;
        }

        // Если пользователь смотрит другой месяц и открывает mini свайпом,
        // сохраняем контекст именно этого месяца.
        final lastDayOfMonth = DateTime(
          _visibleMonth.year,
          _visibleMonth.month + 1,
          0,
        ).day;

        final targetDay = now.day > lastDayOfMonth ? lastDayOfMonth : now.day;

        _openDateInCompact(
          DateTime(_visibleMonth.year, _visibleMonth.month, targetDay),
        );
      }
    }
  }

  void _handleCalendarMenuAction(_CalendarMenuAction action) {
    switch (action) {
      case _CalendarMenuAction.crew:
        unawaited(_openCalendarSettings());
        break;

      case _CalendarMenuAction.vacations:
        unawaited(_openVacationPeriods());
        break;

      case _CalendarMenuAction.alarms:
        unawaited(_openShiftAlarms());
        break;

      case _CalendarMenuAction.themes:
        unawaited(_openCalendarThemeSettings());
        break;
    }
  }

  Future<void> _openVacationPeriods() async {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      return;
    }

    final calendarYear = _viewMode == ShiftCalendarViewMode.compact
        ? _compactFocusedDate.year
        : _visibleMonth.year;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return VacationPeriodsScreen(
            calendarYear: calendarYear,
            userId: userId,
            initialPeriods: _vacationPeriods,
            service: _vacationPeriodService,
            onPeriodsChanged: (periods) {
              if (!mounted) {
                return;
              }

              setState(() {
                _vacationPeriods = periods;
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calendarPalette = _calendarThemeState.activePalette;
    final calendarColors = _CalendarColors.fromPalette(calendarPalette);
    final crew = _effectiveCrew;

    if (!_isAssignedCrewLoaded) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_assignedCrewLoadFailed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Календарь смен')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Не удалось загрузить ваше звено.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (crew == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Календарь смен')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.groups_2_outlined,
                      size: 52,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Вы не выбрали ваше звено',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Звено нужно, чтобы показать ваш рабочий график.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        unawaited(_openAssignedCrewSetup());
                      },
                      icon: const Icon(Icons.groups_2_outlined),
                      label: const Text('Выбрать звено'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final isCurrentMonth =
        _visibleMonth.year == today.year && _visibleMonth.month == today.month;

    final DateTime? headerDate = switch (_viewMode) {
      ShiftCalendarViewMode.full => isCurrentMonth ? today : null,
      ShiftCalendarViewMode.compact => _selectedDate,
    };

    final headerMonth = switch (_viewMode) {
      ShiftCalendarViewMode.full => _visibleMonth,
      ShiftCalendarViewMode.compact => DateTime(
        _selectedDate.year,
        _selectedDate.month,
      ),
    };

    final monthHoursSummary = _monthHoursCalculator.calculate(
      month: headerMonth,
      crew: crew,
      vacationPeriods: _vacationPeriods,
      additionalShifts: _additionalShiftEvents,
    );

    final ShiftCyclePhase? headerPhase = headerDate == null
        ? null
        : _calculator.phaseFor(date: headerDate, crew: crew);

    final showToday = switch (_viewMode) {
      ShiftCalendarViewMode.full => !isCurrentMonth,
      ShiftCalendarViewMode.compact => !_isSameDay(_selectedDate, today),
    };

    Widget buildMonthPager() {
      return PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, page) {
          final monthOffset = page - _initialPage;
          final month = DateTime(
            _baseMonth.year,
            _baseMonth.month + monthOffset,
          );
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          final isCurrentMonth =
              month.year == today.year && month.month == today.month;

          final highlightedDate = isCurrentMonth ? today : null;

          return _MonthGrid(
            month: month,
            selectedDate: highlightedDate,
            crew: crew,
            calculator: _calculator,
            vacationPeriods: _vacationPeriods,
            onDateSelected: _openDateInCompact,
            entryMarkersForDate: _entryMarkersForDate,
            hasAdditionalShiftForDate: _hasAdditionalShiftForDate,
            colorScheme: calendarColors,
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: calendarColors.background,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: _handleVerticalDragEnd,
          child: Column(
            children: [
              _CalendarHeader(
                visibleMonth: headerMonth,
                activeDate: headerDate,
                selectedPhase: headerPhase,
                crew: crew,
                isPreviewingCrew: _isPreviewingCrew,
                showToday: showToday,
                foregroundColor: calendarColors.foreground,
                onBackTap: () {
                  Navigator.of(context).maybePop();
                },
                onTodayTap: _goToToday,
                onMenuSelected: _handleCalendarMenuAction,
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 550),
                  reverseDuration: const Duration(milliseconds: 520),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                    );

                    return FadeTransition(
                      opacity: curvedAnimation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.995,
                          end: 1,
                        ).animate(curvedAnimation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_viewMode),
                    child: switch (_viewMode) {
                      ShiftCalendarViewMode.full => Column(
                        children: [
                          const SizedBox(height: 4),
                          _WeekdayHeader(
                            foregroundColor: calendarColors.foreground,
                          ),
                          const SizedBox(height: 4),
                          Expanded(child: buildMonthPager()),
                        ],
                      ),

                      ShiftCalendarViewMode.compact => Column(
                        children: [
                          const SizedBox(height: 8),
                          _CompactDateStrip(
                            key: ValueKey(_compactStripRevision),
                            selectedDate: _selectedDate,
                            calculator: _calculator,
                            crew: crew,
                            vacationPeriods: _vacationPeriods,
                            colors: calendarColors,
                            onDateSelected: (date) {
                              setState(() {
                                _selectedDate = date;
                                _hasSelectedDate = true;
                              });
                            },
                            onFocusedDateChanged: (date) {
                              setState(() {
                                _compactFocusedDate = date;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _CalendarAgendaPanel(
                              key: ValueKey(_selectedDate),
                              selectedDate: _selectedDate,
                              userId: _currentUserId,
                              service: _calendarEntryService,
                              palette: calendarPalette,
                              additionalShiftEvents: _additionalShiftsForDate(
                                _selectedDate,
                              ),
                              onAddEntry: _openCalendarEntryEditor,
                              onEntriesChanged: _loadCalendarEntries,
                            ),
                          ),
                        ],
                      ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),

              _MonthHoursSummaryBar(
                summary: monthHoursSummary,
                colors: calendarColors,
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthHoursSummaryBar extends StatelessWidget {
  const _MonthHoursSummaryBar({required this.summary, required this.colors});

  final ShiftMonthHoursSummary summary;
  final _CalendarColors colors;

  @override
  Widget build(BuildContext context) {
    final foreground = _calendarContrastColor(colors.monthHoursBar);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.monthHoursBar,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: _MonthHoursValue(
                label: 'Основные',
                minutes: summary.regularMinutes,
                foregroundColor: foreground,
              ),
            ),
            _MonthHoursDivider(color: foreground.withValues(alpha: 0.24)),
            Expanded(
              child: _MonthHoursValue(
                label: 'Халтуры',
                minutes: summary.additionalMinutes,
                foregroundColor: foreground,
              ),
            ),
            _MonthHoursDivider(color: foreground.withValues(alpha: 0.24)),
            Expanded(
              child: _MonthHoursValue(
                label: 'Всего',
                minutes: summary.totalMinutes,
                emphasize: true,
                foregroundColor: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHoursValue extends StatelessWidget {
  const _MonthHoursValue({
    required this.label,
    required this.minutes,
    required this.foregroundColor,
    this.emphasize = false,
  });

  final String label;
  final int minutes;
  final Color foregroundColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: foregroundColor.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatHours(minutes),
          maxLines: 1,
          style: theme.textTheme.titleMedium?.copyWith(
            color: foregroundColor,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static String _formatHours(int minutes) {
    final wholeHours = minutes ~/ 60;
    final remainder = minutes % 60;

    if (remainder == 0) {
      return '$wholeHours ч';
    }

    if (remainder == 30) {
      return '$wholeHours,5 ч';
    }

    final decimalHours = minutes / 60;

    return '${decimalHours.toStringAsFixed(1).replaceAll('.', ',')} ч';
  }
}

class _MonthHoursDivider extends StatelessWidget {
  const _MonthHoursDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: color,
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.visibleMonth,
    required this.activeDate,
    required this.selectedPhase,
    required this.crew,
    required this.showToday,
    required this.onBackTap,
    required this.onTodayTap,
    required this.onMenuSelected,
    required this.isPreviewingCrew,
    required this.foregroundColor,
  });

  final DateTime visibleMonth;
  final DateTime? activeDate;
  final ShiftCyclePhase? selectedPhase;
  final ShiftCrew crew;
  final bool isPreviewingCrew;
  final bool showToday;

  final VoidCallback onBackTap;
  final VoidCallback onTodayTap;
  final ValueChanged<_CalendarMenuAction> onMenuSelected;
  final Color foregroundColor;

  static const _months = <String>[
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  static const _monthsGenitive = <String>[
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = activeDate;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Column(
        children: [
          SizedBox(
            height: 42,
            child: Row(
              children: [
                IconButton(
                  onPressed: onBackTap,
                  tooltip: 'Назад',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.arrow_back, color: foregroundColor),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: date != null
                      ? Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${date.day}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' ${_monthsGenitive[date.month - 1]} '
                                    '${date.year}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          '${_months[visibleMonth.month - 1]} '
                          '${visibleMonth.year}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                PopupMenuButton<_CalendarMenuAction>(
                  tooltip: 'Настройки календаря',
                  onSelected: onMenuSelected,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _CalendarMenuAction.crew,
                      child: Text(
                        isPreviewingCrew
                            ? '${crew.displayName} · просмотр'
                            : crew.displayName,
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: _CalendarMenuAction.vacations,
                      child: Text('Отпуска'),
                    ),
                    const PopupMenuItem(
                      value: _CalendarMenuAction.alarms,
                      child: Text('Будильники'),
                    ),
                    const PopupMenuItem(
                      value: _CalendarMenuAction.themes,
                      child: Text('Темы календаря'),
                    ),
                  ],
                  icon: Icon(Icons.settings_outlined, color: foregroundColor),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: selectedPhase == null
                      ? const SizedBox.shrink()
                      : Text(
                          selectedPhase!.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: foregroundColor.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                if (showToday)
                  TextButton(
                    onPressed: onTodayTap,
                    style: TextButton.styleFrom(
                      foregroundColor: foregroundColor,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Сегодня'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.foregroundColor});

  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    const weekdays = <String>['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (final weekday in weekdays)
            Expanded(
              child: Center(
                child: Text(
                  weekday,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foregroundColor.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    this.selectedDate,
    required this.crew,
    required this.calculator,
    required this.onDateSelected,
    required this.colorScheme,
    required this.vacationPeriods,
    required this.entryMarkersForDate,
    required this.hasAdditionalShiftForDate,
  });

  final DateTime month;
  final DateTime? selectedDate;
  final ShiftCrew crew;
  final ShiftScheduleCalculator calculator;
  final List<VacationPeriod> vacationPeriods;
  final ValueChanged<DateTime> onDateSelected;
  final _CalendarColors colorScheme;
  final CalendarEntryDayMarkers Function(DateTime date) entryMarkersForDate;
  final bool Function(DateTime date) hasAdditionalShiftForDate;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);

    // weekday: Monday = 1 ... Sunday = 7.
    final leadingDays = firstDay.weekday - 1;

    final firstVisibleDate = firstDay.subtract(Duration(days: leadingDays));

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final requiredCells = leadingDays + daysInMonth;
    final rowCount = (requiredCells / 7).ceil();
    final itemCount = rowCount * 7;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellHeight = constraints.maxHeight / 6;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: cellHeight,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            final date = firstVisibleDate.add(Duration(days: index));
            final phase = calculator.phaseFor(date: date, crew: crew);
            final isVacation = _isVacationDate(date, vacationPeriods);

            final isAdditionalShift =
                !isVacation && hasAdditionalShiftForDate(date);

            return _CalendarDayTile(
              date: date,
              phase: phase,
              isCurrentMonth: date.month == month.month,
              isToday: _isSameDay(date, DateTime.now()),
              isSelected:
                  selectedDate != null && _isSameDay(date, selectedDate!),
              isVacation: isVacation,
              isAdditionalShift: isAdditionalShift,
              colors: colorScheme,
              entryMarkers: entryMarkersForDate(date),
              onTap: () => onDateSelected(date),
            );
          },
        );
      },
    );
  }
}

class _CompactDateStrip extends StatefulWidget {
  const _CompactDateStrip({
    super.key,
    required this.selectedDate,
    required this.calculator,
    required this.crew,
    required this.vacationPeriods,
    required this.onDateSelected,
    required this.onFocusedDateChanged,
    required this.colors,
  });

  final DateTime selectedDate;
  final ShiftScheduleCalculator calculator;
  final ShiftCrew crew;
  final List<VacationPeriod> vacationPeriods;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onFocusedDateChanged;
  final _CalendarColors colors;

  @override
  State<_CompactDateStrip> createState() => _CompactDateStripState();
}

class _CompactDateStripState extends State<_CompactDateStrip> {
  static const int _initialPage = 10000;

  static const _weekdays = <String>['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  late final DateTime _anchorDate;
  late PageController _pageController;

  late DateTime _focusedDate;
  static const _selectionSettleDelay = Duration(milliseconds: 250);

  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();

    _anchorDate = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );

    _focusedDate = _anchorDate;

    _pageController = PageController(
      initialPage: _initialPage,
      viewportFraction: 1 / 7,
    );
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  DateTime _dateForPage(int page) {
    return _anchorDate.add(Duration(days: page - _initialPage));
  }

  int _pageForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    return _initialPage + normalizedDate.difference(_anchorDate).inDays;
  }

  void _handlePageChanged(int page) {
    final date = _dateForPage(page);

    setState(() {
      _focusedDate = date;
    });
  }

  void _scheduleSettledSelection(DateTime date) {
    _settleTimer?.cancel();

    _settleTimer = Timer(_selectionSettleDelay, () {
      if (!mounted) {
        return;
      }

      widget.onFocusedDateChanged(date);
      widget.onDateSelected(date);
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _settleTimer?.cancel();
    }

    if (notification is ScrollEndNotification) {
      final page = _pageController.page?.round() ?? _initialPage;

      _scheduleSettledSelection(_dateForPage(page));
    }

    return false;
  }

  void _handleDateTap(DateTime date) {
    final targetPage = _pageForDate(date);

    final currentPage = _pageController.hasClients
        ? (_pageController.page?.round() ?? _initialPage)
        : _initialPage;

    if (targetPage == currentPage) {
      _scheduleSettledSelection(date);
      return;
    }

    _settleTimer?.cancel();

    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = widget.colors;

    return SizedBox(
      height: 96,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final focusedItemWidth = constraints.maxWidth / 7;

          return Stack(
            alignment: Alignment.center,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _handlePageChanged,
                  itemBuilder: (context, page) {
                    final date = _dateForPage(page);

                    final phase = widget.calculator.phaseFor(
                      date: date,
                      crew: widget.crew,
                    );

                    final tileBackground = colors.forPhase(phase);
                    final tileForeground = _calendarContrastColor(
                      tileBackground,
                    );

                    final isSelected = _isSameDay(date, widget.selectedDate);

                    final isFocused = _isSameDay(date, _focusedDate);

                    final isVacation = _isVacationDate(
                      date,
                      widget.vacationPeriods,
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleDateTap(date),
                        child: Container(
                          decoration: BoxDecoration(
                            color: tileBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.gridLine,
                              width: 0.7,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 7,
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _weekdays[date.weekday - 1],
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: tileForeground.withValues(
                                              alpha: 0.72,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${date.day}',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontSize:
                                                (isSelected
                                                    ? 20
                                                    : isFocused
                                                    ? 17
                                                    : 16) *
                                                colors.textScale,
                                            color: isSelected
                                                ? colors.selectedDay
                                                : tileForeground,
                                            fontWeight: isSelected || isFocused
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      phase.displayLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontSize: 10 * colors.textScale,
                                            color: tileForeground.withValues(
                                              alpha: 0.82,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isVacation)
                                Positioned(
                                  left: 6,
                                  right: 6,
                                  bottom: 0,
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: colors.vacationMarker,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              IgnorePointer(
                child: SizedBox(
                  width: focusedItemWidth - 2,
                  height: 96,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: colors.selectedDay.withValues(alpha: 0.95),
                              width: 2.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.selectedDay.withValues(
                                  alpha: 0.16,
                                ),
                                blurRadius: 5,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -3,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.selectedDay,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -3,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.selectedDay,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CalendarAgendaPanel extends StatefulWidget {
  const _CalendarAgendaPanel({
    super.key,
    required this.selectedDate,
    required this.userId,
    required this.service,
    required this.onAddEntry,
    required this.onEntriesChanged,
    required this.additionalShiftEvents,
    required this.palette,
  });

  final DateTime selectedDate;
  final String userId;
  final CalendarEntryService service;
  final Future<void> Function(CalendarEntryKind kind) onAddEntry;
  final Future<void> Function() onEntriesChanged;
  final List<CalendarAdditionalShiftEvent> additionalShiftEvents;
  final ShiftCalendarThemePalette palette;

  @override
  State<_CalendarAgendaPanel> createState() => _CalendarAgendaPanelState();
}

class _CalendarAgendaPanelState extends State<_CalendarAgendaPanel> {
  static const _months = <String>[
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  static const _weekdays = <String>[
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  late Future<List<CalendarEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadEntries();
  }

  @override
  void didUpdateWidget(covariant _CalendarAgendaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate) ||
        oldWidget.userId != widget.userId) {
      _entriesFuture = _loadEntries();
    }
  }

  Future<List<CalendarEntry>> _loadEntries() {
    if (widget.userId.trim().isEmpty) {
      return Future<List<CalendarEntry>>.value(const <CalendarEntry>[]);
    }

    return widget.service.loadForDay(
      userId: widget.userId,
      date: widget.selectedDate,
    );
  }

  void _reloadEntries() {
    setState(() {
      _entriesFuture = _loadEntries();
    });
  }

  Future<void> _handleAddEntry(CalendarEntryKind kind) async {
    await widget.onAddEntry(kind);

    if (!mounted) {
      return;
    }

    _reloadEntries();
    await widget.onEntriesChanged();
  }

  Future<void> _editEntry(CalendarEntry entry) async {
    final result = await Navigator.of(context).push<CalendarEntryEditorResult>(
      MaterialPageRoute(
        builder: (context) {
          return CalendarEntryEditorScreen(
            kind: entry.kind,
            date: entry.date,
            initialEntry: entry,
            palette: widget.palette,
          );
        },
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    try {
      switch (result.action) {
        case CalendarEntryEditorAction.save:
          var reminderMinutes = result.reminderMinutes;

          if (reminderMinutes != null) {
            final permissionGranted = await widget.service
                .ensureReminderPermission();

            if (!mounted) {
              return;
            }

            if (!permissionGranted) {
              reminderMinutes = null;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Разрешение на точные напоминания не выдано. '
                    'Запись сохранена без будильника.',
                  ),
                ),
              );
            }
          }

          await widget.service.update(
            userId: widget.userId,
            currentEntry: entry,
            kind: result.kind,
            date: result.date,
            title: result.title,
            description: result.description,
            scheduledMinutes: result.scheduledMinutes,
            reminderMinutes: reminderMinutes,
            priority: result.priority,
            colorValue: entry.colorValue,
          );

        case CalendarEntryEditorAction.delete:
          await widget.service.delete(userId: widget.userId, entry: entry);
      }

      if (!mounted) {
        return;
      }

      _reloadEntries();
      await widget.onEntriesChanged();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить запись')),
      );
    }
  }

  Future<void> _setCompleted(CalendarEntry entry, bool isCompleted) async {
    try {
      await widget.service.setCompleted(
        userId: widget.userId,
        entry: entry,
        isCompleted: isCompleted,
      );

      if (!mounted) {
        return;
      }

      _reloadEntries();
      await widget.onEntriesChanged();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось изменить дело')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _CalendarColors.fromPalette(widget.palette);

    final panelBackground = _calendarLayerColor(colors.background, 0.05);
    final panelForeground = _calendarContrastColor(panelBackground);
    final panelSecondary = panelForeground.withValues(alpha: 0.72);

    final controlRailBackground = _calendarLayerColor(panelBackground, 0.06);
    final controlButtonBackground = _calendarLayerColor(panelBackground, 0.10);
    final controlForeground = _calendarContrastColor(controlButtonBackground);

    final errorColor =
        ThemeData.estimateBrightnessForColor(panelBackground) == Brightness.dark
        ? const Color(0xFFFF8A80)
        : const Color(0xFFB3261E);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: panelBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Дела',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: panelForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_weekdays[widget.selectedDate.weekday - 1]}, '
                  '${widget.selectedDate.day} '
                  '${_months[widget.selectedDate.month - 1]}',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: panelSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<CalendarEntry>>(
              future: _entriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.selectedDay,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'Не удалось загрузить дела',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: errorColor,
                      ),
                    ),
                  );
                }

                final entries = snapshot.data ?? const <CalendarEntry>[];
                final additionalShiftEvents = widget.additionalShiftEvents;

                if (entries.isEmpty && additionalShiftEvents.isEmpty) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'На этот день пока ничего не запланировано',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: panelSecondary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 18),
                  itemCount: additionalShiftEvents.length + entries.length,
                  itemBuilder: (context, index) {
                    if (index < additionalShiftEvents.length) {
                      return _CalendarAdditionalShiftListItem(
                        event: additionalShiftEvents[index],
                        foregroundColor: panelForeground,
                        accentColor: colors.additionalShiftMarker,
                      );
                    }

                    final entry = entries[index - additionalShiftEvents.length];

                    return _CalendarEntryListItem(
                      entry: entry,
                      foregroundColor: panelForeground,
                      accentColor: colors.selectedDay,
                      onTap: () {
                        _editEntry(entry);
                      },
                      onCompletedChanged: entry.kind == CalendarEntryKind.task
                          ? (value) {
                              _setCompleted(entry, value);
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: controlRailBackground,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: controlButtonBackground,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        _handleAddEntry(CalendarEntryKind.task);
                      },
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 19,
                              color: controlForeground,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Дело',
                              style: TextStyle(color: controlForeground),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Добавить',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: panelSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: controlButtonBackground,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        _handleAddEntry(CalendarEntryKind.note);
                      },
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 19,
                              color: controlForeground,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Заметка',
                              style: TextStyle(color: controlForeground),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _CalendarAdditionalShiftListItem extends StatelessWidget {
  const _CalendarAdditionalShiftListItem({
    required this.event,
    required this.foregroundColor,
    required this.accentColor,
  });

  final CalendarAdditionalShiftEvent event;
  final Color foregroundColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = switch (event.kind) {
      SubstitutionShiftKind.day => 'Дополнительная дневная смена',
      SubstitutionShiftKind.night => 'Дополнительная ночная смена',
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 48,
        child: Center(
          child: Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CalendarEntryListItem extends StatelessWidget {
  const _CalendarEntryListItem({
    required this.entry,
    required this.foregroundColor,
    required this.accentColor,
    required this.onTap,
    required this.onCompletedChanged,
  });

  final CalendarEntry entry;
  final Color foregroundColor;
  final Color accentColor;
  final VoidCallback onTap;
  final ValueChanged<bool>? onCompletedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = entry.isCompleted;

    final subtitleParts = <String>[];

    if (entry.scheduledMinutes != null) {
      subtitleParts.add(_formatMinutes(entry.scheduledMinutes!));
    }

    final description = entry.description?.trim();

    if (description != null && description.isNotEmpty) {
      subtitleParts.add(description);
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: entry.kind == CalendarEntryKind.task
          ? Checkbox(
              value: isCompleted,
              activeColor: accentColor,
              checkColor: _calendarContrastColor(accentColor),
              side: BorderSide(color: foregroundColor.withValues(alpha: 0.55)),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                onCompletedChanged?.call(value);
              },
            )
          : SizedBox(
              width: 48,
              child: Icon(
                Icons.sticky_note_2_outlined,
                color: foregroundColor.withValues(alpha: 0.82),
              ),
            ),
      title: Text(
        entry.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted
              ? foregroundColor.withValues(alpha: 0.55)
              : foregroundColor,
        ),
      ),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(
              subtitleParts.join(' · '),
              style: TextStyle(color: foregroundColor.withValues(alpha: 0.72)),
            ),
      trailing: entry.hasReminder
          ? Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: foregroundColor.withValues(alpha: 0.82),
            )
          : null,
    );
  }

  static String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}

class _CalendarDayTile extends StatelessWidget {
  const _CalendarDayTile({
    required this.date,
    required this.phase,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.isVacation,
    required this.isAdditionalShift,
    required this.entryMarkers,
    required this.colors,
    required this.onTap,
  });

  final DateTime date;
  final ShiftCyclePhase phase;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool isVacation;
  final bool isAdditionalShift;

  final CalendarEntryDayMarkers entryMarkers;
  final _CalendarColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final background = colors.forPhase(phase);

    final selectedBackground = isSelected
        ? Color.lerp(background, colors.selectedDay, 0.20)!
        : background;

    final foreground = _calendarContrastColor(selectedBackground);

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Material(
        color: selectedBackground,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isAdditionalShift
                    ? colors.additionalShiftMarker
                    : colors.gridLine,
                width: isAdditionalShift ? 2.2 : 0.7,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: isCurrentMonth ? 1 : 0.30,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        6,
                        4,
                        5,
                        isVacation ? 10 : 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 26,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: Text(
                                  '${date.day}',
                                  maxLines: 1,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontSize:
                                        (isSelected ? 20 : 14) *
                                        colors.textScale,
                                    color: isSelected
                                        ? colors.selectedDay
                                        : foreground,
                                    fontWeight: isToday || isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            phase.displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11 * colors.textScale,
                              color: foreground.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (entryMarkers.hasAnyMarker)
                  Positioned(
                    top: 4,
                    right: 5,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (entryMarkers.hasPlainEntry)
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 11,
                            color: foreground.withValues(alpha: 0.82),
                          ),
                        if (entryMarkers.hasPlainEntry &&
                            entryMarkers.hasPriority)
                          const SizedBox(width: 3),
                        if (entryMarkers.hasPriority)
                          _CalendarPriorityDot(
                            priority: entryMarkers.highestPriority,
                          ),
                        if (entryMarkers.hasPriority &&
                            entryMarkers.hasReminder)
                          const SizedBox(width: 3),
                        if (entryMarkers.hasReminder)
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 12,
                            color: foreground.withValues(alpha: 0.88),
                          ),
                      ],
                    ),
                  ),
                if (isVacation)
                  Positioned(
                    left: 7,
                    right: 7,
                    bottom: 4,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.vacationMarker,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarPriorityDot extends StatelessWidget {
  const _CalendarPriorityDot({required this.priority});

  final CalendarEntryPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      CalendarEntryPriority.none => Colors.transparent,
      CalendarEntryPriority.low => Colors.green,
      CalendarEntryPriority.medium => Colors.amber,
      CalendarEntryPriority.high => Colors.red,
    };

    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CalendarColors {
  const _CalendarColors({
    required this.day1,
    required this.day2,
    required this.offBeforeNight,
    required this.night1,
    required this.night2,
    required this.recovery,
    required this.offAfterRecovery1,
    required this.offAfterRecovery2,
    required this.background,
    required this.foreground,
    required this.gridLine,
    required this.vacationMarker,
    required this.additionalShiftMarker,
    required this.selectedDay,
    required this.monthHoursBar,
    required this.textScale,
  });

  final Color day1;
  final Color day2;
  final Color offBeforeNight;
  final Color night1;
  final Color night2;
  final Color recovery;
  final Color offAfterRecovery1;
  final Color offAfterRecovery2;

  final Color background;
  final Color foreground;
  final Color gridLine;
  final Color vacationMarker;
  final Color additionalShiftMarker;
  final Color selectedDay;
  final Color monthHoursBar;

  final double textScale;

  factory _CalendarColors.fromPalette(ShiftCalendarThemePalette palette) {
    final background = Color(palette.background);

    final isDark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

    final foreground = isDark ? Colors.white : Colors.black;

    final gridLine = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);

    return _CalendarColors(
      day1: Color(palette.day1),
      day2: Color(palette.day2),
      offBeforeNight: Color(palette.offBeforeNight),
      night1: Color(palette.night1),
      night2: Color(palette.night2),
      recovery: Color(palette.recovery),
      offAfterRecovery1: Color(palette.offAfterRecovery1),
      offAfterRecovery2: Color(palette.offAfterRecovery2),
      background: background,
      foreground: foreground,
      gridLine: gridLine,
      vacationMarker: Color(palette.vacation),
      additionalShiftMarker: Color(palette.additionalShift),
      selectedDay: Color(palette.selectedDay),
      monthHoursBar: Color(palette.monthHoursBar),
      textScale: palette.textScale.factor,
    );
  }

  Color forPhase(ShiftCyclePhase phase) {
    return switch (phase) {
      ShiftCyclePhase.day1 => day1,
      ShiftCyclePhase.day2 => day2,
      ShiftCyclePhase.offBeforeNight => offBeforeNight,
      ShiftCyclePhase.night1 => night1,
      ShiftCyclePhase.night2 => night2,
      ShiftCyclePhase.recovery => recovery,
      ShiftCyclePhase.offAfterRecovery1 => offAfterRecovery1,
      ShiftCyclePhase.offAfterRecovery2 => offAfterRecovery2,
    };
  }
}

Color _calendarLayerColor(Color background, double amount) {
  final foreground = _calendarContrastColor(background);

  return Color.lerp(background, foreground, amount)!;
}

Color _calendarContrastColor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

bool _isVacationDate(DateTime date, List<VacationPeriod> periods) {
  return periods.any((period) => period.contains(date));
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
