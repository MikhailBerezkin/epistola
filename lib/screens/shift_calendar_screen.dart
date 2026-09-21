import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/models/shift_cycle.dart';
import '../domain/models/vacation_period.dart';
import '../services/spaces/calendar/shift_calendar_settings.dart';
import '../services/spaces/calendar/shift_schedule_calculator.dart';
import '../services/spaces/calendar/vacation_period_service.dart';
import 'shift_calendar_settings_screen.dart';
import 'vacation_periods_screen.dart';
import '../domain/models/calendar_entry.dart';
import 'calendar_entry_editor_screen.dart';
import '../services/spaces/calendar/calendar_entry_local_store.dart';
import '../services/spaces/calendar/calendar_entry_service.dart';
import '../services/spaces/calendar/calendar_entry_day_markers.dart';

enum _CalendarMenuAction { crew, vacations, alarms, themes }

class ShiftCalendarScreen extends StatefulWidget {
  const ShiftCalendarScreen({super.key});

  @override
  State<ShiftCalendarScreen> createState() => _ShiftCalendarScreenState();
}

class _ShiftCalendarScreenState extends State<ShiftCalendarScreen> {
  static const _initialPage = 1200;

  final ShiftScheduleCalculator _calculator = const ShiftScheduleCalculator();

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

  ShiftCalendarViewMode _viewMode = ShiftCalendarViewMode.medium;

  // Пока первая версия открывается для 4 звена.
  final ShiftCalendarSettings _settings = const ShiftCalendarSettings();

  ShiftCrew _crew = ShiftCrew.crew4;
  bool _areSettingsLoaded = false;
  late final VacationPeriodService _vacationPeriodService;

  StreamSubscription<List<VacationPeriod>>? _vacationPeriodsSubscription;

  List<VacationPeriod> _vacationPeriods = const <VacationPeriod>[];

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
    _watchVacationPeriods();
    _loadSettings();
  }

  Future<void> _openCalendarEntryEditor(CalendarEntryKind kind) async {
    if (!_hasSelectedDate) {
      return;
    }

    final result = await Navigator.of(context).push<CalendarEntryEditorResult>(
      MaterialPageRoute(
        builder: (context) {
          return CalendarEntryEditorScreen(kind: kind, date: _selectedDate);
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

  Future<void> _loadSettings() async {
    final results = await Future.wait<Object>([
      _settings.loadCrew(),
      _settings.loadViewMode(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _crew = results[0] as ShiftCrew;
      _viewMode = results[1] as ShiftCalendarViewMode;
      _areSettingsLoaded = true;
    });

    await _loadCalendarEntries();
    await _reconcileCalendarReminders();
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

    unawaited(_settings.saveViewMode(viewMode));
  }

  Future<void> _openCalendarSettings() async {
    final crew = await Navigator.of(context).push<ShiftCrew>(
      MaterialPageRoute(
        builder: (_) => ShiftCalendarSettingsScreen(initialCrew: _crew),
      ),
    );

    if (!mounted || crew == null || crew == _crew) {
      return;
    }

    setState(() {
      _crew = crew;
    });
  }

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
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
          },
          onError: (Object error, StackTrace stackTrace) {
            // Ошибка Firestore не должна ломать сам календарь.
            // До deploy Vacation Rules календарь просто останется
            // без сохранённых отпусков.
          },
        );
  }

  @override
  void dispose() {
    final subscription = _vacationPeriodsSubscription;

    if (subscription != null) {
      unawaited(subscription.cancel());
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
    final targetPage = _pageForMonth(todayMonth);

    if (_pageController.hasClients) {
      setState(() {
        _visibleMonth = todayMonth;
        _selectedDate = today;
        _hasSelectedDate = true;
        _compactFocusedDate = today;
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
      _hasSelectedDate = true;
      _compactFocusedDate = today;
      _compactStripRevision++;
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    // Свайп вниз: compact -> medium -> full.
    if (velocity > 250) {
      if (_viewMode == ShiftCalendarViewMode.compact) {
        _setViewMode(ShiftCalendarViewMode.medium);
        return;
      }

      if (_viewMode == ShiftCalendarViewMode.medium) {
        _setViewMode(ShiftCalendarViewMode.full);
      }

      return;
    }

    // Свайп вверх: full -> medium -> compact.
    if (velocity < -250) {
      if (_viewMode == ShiftCalendarViewMode.full) {
        _setViewMode(ShiftCalendarViewMode.medium);
        return;
      }

      if (_viewMode == ShiftCalendarViewMode.medium) {
        _setViewMode(ShiftCalendarViewMode.compact);
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
        break;

      case _CalendarMenuAction.themes:
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
    if (!_areSettingsLoaded) {
      return Scaffold(
        appBar: AppBar(
          actions: [
            TextButton(onPressed: _goToToday, child: const Text('Сегодня')),
          ],
        ),
        body: const SafeArea(child: SizedBox.expand()),
      );
    }

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

          return _MonthGrid(
            month: month,
            selectedDate: _selectedDate,
            crew: _crew,
            calculator: _calculator,
            vacationPeriods: _vacationPeriods,
            onDateSelected: (date) {
              setState(() {
                _selectedDate = date;
                _hasSelectedDate = true;
              });
            },
            entryMarkersForDate: _entryMarkersForDate,
            colorScheme: _CalendarColors.fromTheme(theme),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: _handleVerticalDragEnd,
          child: Column(
            children: [
              _CalendarHeader(
                visibleMonth: _viewMode == ShiftCalendarViewMode.compact
                    ? DateTime(
                        _compactFocusedDate.year,
                        _compactFocusedDate.month,
                      )
                    : _visibleMonth,
                selectedDate: _selectedDate,
                hasSelectedDate: _hasSelectedDate,
                selectedPhase: _calculator.phaseFor(
                  date: _selectedDate,
                  crew: _crew,
                ),
                crew: _crew,
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
                          const _WeekdayHeader(),
                          const SizedBox(height: 4),
                          Expanded(child: buildMonthPager()),
                        ],
                      ),

                      ShiftCalendarViewMode.medium => Column(
                        children: [
                          const SizedBox(height: 4),
                          const _WeekdayHeader(),
                          const SizedBox(height: 4),
                          if (_hasSelectedDate) ...[
                            Expanded(flex: 6, child: buildMonthPager()),
                            const SizedBox(height: 6),
                            Expanded(
                              flex: 4,
                              child: _CalendarAgendaPanel(
                                selectedDate: _selectedDate,
                                userId: _currentUserId,
                                service: _calendarEntryService,
                                onAddEntry: _openCalendarEntryEditor,
                                onEntriesChanged: _loadCalendarEntries,
                              ),
                            ),
                          ] else
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
                            crew: _crew,
                            vacationPeriods: _vacationPeriods,
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
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _hasSelectedDate
                                  ? _CalendarAgendaPanel(
                                      key: ValueKey(_selectedDate),
                                      selectedDate: _selectedDate,
                                      userId: _currentUserId,
                                      service: _calendarEntryService,
                                      onAddEntry: _openCalendarEntryEditor,
                                      onEntriesChanged: _loadCalendarEntries,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.visibleMonth,
    required this.selectedDate,
    required this.hasSelectedDate,
    required this.crew,
    required this.onTodayTap,
    required this.onMenuSelected,
    required this.selectedPhase,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final bool hasSelectedDate;
  final ShiftCrew crew;
  final VoidCallback onTodayTap;
  final ValueChanged<_CalendarMenuAction> onMenuSelected;
  final ShiftCyclePhase selectedPhase;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final monthTitle =
        '${_months[visibleMonth.month - 1]} ${visibleMonth.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0, 0.35),
                        end: Offset.zero,
                      ).animate(animation);

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      monthTitle,
                      key: ValueKey(
                        '${visibleMonth.year}-${visibleMonth.month}',
                      ),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              PopupMenuButton<_CalendarMenuAction>(
                tooltip: 'Настройки календаря',
                onSelected: onMenuSelected,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _CalendarMenuAction.crew,
                    child: Text(crew.displayName),
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
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: hasSelectedDate
                      ? Text(
                          selectedPhase.displayTitle,
                          key: ValueKey(selectedPhase),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              IconButton(
                onPressed: onTodayTap,
                tooltip: 'Вернуться к сегодня',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.replay_rounded, size: 21),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
    required this.selectedDate,
    required this.crew,
    required this.calculator,
    required this.onDateSelected,
    required this.colorScheme,
    required this.vacationPeriods,
    required this.entryMarkersForDate,
  });

  final DateTime month;
  final DateTime selectedDate;
  final ShiftCrew crew;
  final ShiftScheduleCalculator calculator;
  final List<VacationPeriod> vacationPeriods;
  final ValueChanged<DateTime> onDateSelected;
  final _CalendarColors colorScheme;
  final CalendarEntryDayMarkers Function(DateTime date) entryMarkersForDate;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);

    // weekday: Monday = 1 ... Sunday = 7.
    final leadingDays = firstDay.weekday - 1;

    final firstVisibleDate = firstDay.subtract(Duration(days: leadingDays));

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
          itemCount: 42,
          itemBuilder: (context, index) {
            final date = firstVisibleDate.add(Duration(days: index));
            final phase = calculator.phaseFor(date: date, crew: crew);

            return _CalendarDayTile(
              date: date,
              phase: phase,
              isCurrentMonth: date.month == month.month,
              isToday: _isSameDay(date, DateTime.now()),
              isSelected: _isSameDay(date, selectedDate),
              isVacation: _isVacationDate(date, vacationPeriods),
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
  });

  final DateTime selectedDate;
  final ShiftScheduleCalculator calculator;
  final ShiftCrew crew;
  final List<VacationPeriod> vacationPeriods;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onFocusedDateChanged;

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
    final colors = _CalendarColors.fromTheme(theme);

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
                            color: colors.forPhase(phase),
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
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${date.day}',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontSize: isSelected
                                                ? 20
                                                : isFocused
                                                ? 17
                                                : 16,
                                            color: isSelected
                                                ? const Color.fromARGB(
                                                    255,
                                                    196,
                                                    8,
                                                    39,
                                                  )
                                                : null,
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
                                            fontSize: 10,
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
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.95,
                              ),
                              width: 2.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
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
                            color: theme.colorScheme.primary,
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
                            color: theme.colorScheme.primary,
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
  });

  final DateTime selectedDate;
  final String userId;
  final CalendarEntryService service;
  final Future<void> Function(CalendarEntryKind kind) onAddEntry;
  final Future<void> Function() onEntriesChanged;

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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
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
                    color: theme.colorScheme.onSurfaceVariant,
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
                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'Не удалось загрузить дела',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  );
                }

                final entries = snapshot.data ?? const <CalendarEntry>[];

                if (entries.isEmpty) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'На этот день пока ничего не запланировано',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 18),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];

                    return _CalendarEntryListItem(
                      entry: entry,
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
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        _handleAddEntry(CalendarEntryKind.task);
                      },
                      child: const SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 19),
                            SizedBox(width: 7),
                            Text('Дело'),
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
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        _handleAddEntry(CalendarEntryKind.note);
                      },
                      child: const SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sticky_note_2_outlined, size: 19),
                            SizedBox(width: 7),
                            Text('Заметка'),
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

class _CalendarEntryListItem extends StatelessWidget {
  const _CalendarEntryListItem({
    required this.entry,
    required this.onTap,
    required this.onCompletedChanged,
  });

  final CalendarEntry entry;
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
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                onCompletedChanged?.call(value);
              },
            )
          : const SizedBox(
              width: 48,
              child: Icon(Icons.sticky_note_2_outlined),
            ),
      title: Text(
        entry.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: entry.hasReminder
          ? const Icon(Icons.notifications_active_outlined, size: 20)
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

  final CalendarEntryDayMarkers entryMarkers;

  final _CalendarColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final background = colors.forPhase(phase);

    final selectedBackground = isSelected
        ? Color.lerp(background, Colors.white, 0.25)!
        : background;

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
              border: Border.all(color: colors.gridLine, width: 0.7),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: isCurrentMonth ? 1 : 0.20,
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
                          Text(
                            '${date.day}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontSize: isSelected ? 20 : 14,
                              color: isSelected
                                  ? const Color.fromARGB(255, 196, 8, 39)
                                  : null,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            phase.displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: theme.textTheme.labelSmall?.copyWith(
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.82),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.88),
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
    required this.day,
    required this.night,
    required this.recovery,
    required this.off,
    required this.gridLine,
    required this.vacationMarker,
  });

  final Color day;
  final Color night;
  final Color recovery;
  final Color off;
  final Color gridLine;
  final Color vacationMarker;

  factory _CalendarColors.fromTheme(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return _CalendarColors(
        day: const Color(0xFF394943),
        night: const Color(0xFF263E42),
        recovery: const Color(0xFF383A43),
        off: const Color(0xFF202327),
        gridLine: const Color(0xFF34383D),
        vacationMarker: theme.colorScheme.tertiary,
      );
    }

    return _CalendarColors(
      day: const Color(0xFFDCEBE4),
      night: const Color(0xFFD5E4E6),
      recovery: const Color(0xFFE3E2E8),
      off: const Color(0xFFF3F4F3),
      gridLine: const Color(0xFFD4D8D6),
      vacationMarker: theme.colorScheme.tertiary,
    );
  }

  Color forPhase(ShiftCyclePhase phase) {
    if (phase.isDayShift) {
      return day;
    }

    if (phase.isNightShift) {
      return night;
    }

    if (phase.isRecovery) {
      return recovery;
    }

    return off;
  }
}

bool _isVacationDate(DateTime date, List<VacationPeriod> periods) {
  return periods.any((period) => period.contains(date));
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
