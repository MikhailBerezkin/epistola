import 'package:flutter/material.dart';

import '../domain/models/shift_cycle.dart';
import '../services/spaces/calendar/shift_schedule_calculator.dart';
import '../services/spaces/calendar/shift_calendar_settings.dart';
import 'shift_calendar_settings_screen.dart';

enum _CalendarViewMode { full, medium, compact }

class ShiftCalendarScreen extends StatefulWidget {
  const ShiftCalendarScreen({super.key});

  @override
  State<ShiftCalendarScreen> createState() => _ShiftCalendarScreenState();
}

class _ShiftCalendarScreenState extends State<ShiftCalendarScreen> {
  static const _initialPage = 1200;

  final ShiftScheduleCalculator _calculator = const ShiftScheduleCalculator();

  late final PageController _pageController;
  late final DateTime _baseMonth;

  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  late DateTime _compactFocusedDate;

  _CalendarViewMode _viewMode = _CalendarViewMode.medium;

  // Пока первая версия открывается для 4 звена.
  final ShiftCalendarSettings _settings = const ShiftCalendarSettings();

  ShiftCrew _crew = ShiftCrew.crew4;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _baseMonth = DateTime(now.year, now.month);
    _visibleMonth = _baseMonth;
    _selectedDate = DateTime(now.year, now.month, now.day);
    _compactFocusedDate = _selectedDate;

    _pageController = PageController(initialPage: _initialPage);
    _loadCrew();
  }

  Future<void> _loadCrew() async {
    final crew = await _settings.loadCrew();

    if (!mounted) {
      return;
    }

    setState(() {
      _crew = crew;
    });
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    final monthOffset = page - _initialPage;
    final month = DateTime(_baseMonth.year, _baseMonth.month + monthOffset);

    setState(() {
      _visibleMonth = month;
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    // Свайп вниз: compact -> medium -> full.
    if (velocity > 250) {
      if (_viewMode == _CalendarViewMode.compact) {
        setState(() {
          _viewMode = _CalendarViewMode.medium;
        });
        return;
      }

      if (_viewMode == _CalendarViewMode.medium) {
        setState(() {
          _viewMode = _CalendarViewMode.full;
        });
      }

      return;
    }

    // Свайп вверх: full -> medium -> compact.
    if (velocity < -250) {
      if (_viewMode == _CalendarViewMode.full) {
        setState(() {
          _viewMode = _CalendarViewMode.medium;
        });
        return;
      }

      if (_viewMode == _CalendarViewMode.medium) {
        setState(() {
          _viewMode = _CalendarViewMode.compact;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            onDateSelected: (date) {
              setState(() {
                _selectedDate = date;
              });
            },
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
                visibleMonth: _viewMode == _CalendarViewMode.compact
                    ? DateTime(
                        _compactFocusedDate.year,
                        _compactFocusedDate.month,
                      )
                    : _visibleMonth,
                selectedDate: _viewMode == _CalendarViewMode.compact
                    ? _compactFocusedDate
                    : _selectedDate,
                crew: _crew,
                onCrewTap: _openCalendarSettings,
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
                      _CalendarViewMode.full => Column(
                        children: [
                          const SizedBox(height: 4),
                          const _WeekdayHeader(),
                          const SizedBox(height: 4),
                          Expanded(child: buildMonthPager()),
                        ],
                      ),

                      _CalendarViewMode.medium => Column(
                        children: [
                          const SizedBox(height: 4),
                          const _WeekdayHeader(),
                          const SizedBox(height: 4),
                          Expanded(flex: 6, child: buildMonthPager()),
                          const SizedBox(height: 6),
                          Expanded(
                            flex: 4,
                            child: _CalendarAgendaPanel(
                              selectedDate: _selectedDate,
                            ),
                          ),
                        ],
                      ),

                      _CalendarViewMode.compact => Column(
                        children: [
                          const SizedBox(height: 8),
                          _CompactDateStrip(
                            selectedDate: _selectedDate,
                            calculator: _calculator,
                            crew: _crew,
                            onDateSelected: (date) {
                              setState(() {
                                _selectedDate = date;
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
                              selectedDate: _selectedDate,
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
    required this.crew,
    required this.onCrewTap,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final ShiftCrew crew;
  final VoidCallback onCrewTap;

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

  static const _weekdays = <String>[
    'понедельник',
    'вторник',
    'среда',
    'четверг',
    'пятница',
    'суббота',
    'воскресенье',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final monthName = _months[visibleMonth.month - 1];
    final selectedWeekday = _capitalize(_weekdays[selectedDate.weekday - 1]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  monthName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${visibleMonth.year}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  selectedWeekday,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onCrewTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    crew.displayName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() + value.substring(1);
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
  });

  final DateTime month;
  final DateTime selectedDate;
  final ShiftCrew crew;
  final ShiftScheduleCalculator calculator;
  final ValueChanged<DateTime> onDateSelected;
  final _CalendarColors colorScheme;

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
              colors: colorScheme,
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
    required this.selectedDate,
    required this.calculator,
    required this.crew,
    required this.onDateSelected,
    required this.onFocusedDateChanged,
  });

  final DateTime selectedDate;
  final ShiftScheduleCalculator calculator;
  final ShiftCrew crew;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onFocusedDateChanged;

  @override
  State<_CompactDateStrip> createState() => _CompactDateStripState();
}

class _CompactDateStripState extends State<_CompactDateStrip> {
  static const int _initialPage = 10000;

  static const _weekdays = <String>['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  late final DateTime _anchorDate;
  late final PageController _pageController;

  late DateTime _focusedDate;

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

    widget.onFocusedDateChanged(date);
  }

  void _handleDateTap(DateTime date) {
    final targetPage = _pageForDate(date);

    widget.onDateSelected(date);

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

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _handleDateTap(date),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.forPhase(phase),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.gridLine, width: 0.7),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekdays[date.weekday - 1],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: isSelected
                            ? 20
                            : isFocused
                            ? 17
                            : 16,
                        color: isSelected
                            ? const Color.fromARGB(255, 196, 8, 39)
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
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarAgendaPanel extends StatelessWidget {
  const _CalendarAgendaPanel({required this.selectedDate});

  final DateTime selectedDate;

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
              const Spacer(),
              Text(
                '${selectedDate.day} ${_months[selectedDate.month - 1]}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'На этот день пока ничего не запланировано',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDayTile extends StatelessWidget {
  const _CalendarDayTile({
    required this.date,
    required this.phase,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final DateTime date;
  final ShiftCyclePhase phase;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
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
            padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
            child: Opacity(
              opacity: isCurrentMonth ? 1 : 0.20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${date.day}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: isSelected ? 20 : 14,
                      color: isSelected
                          ? (theme.brightness == Brightness.dark
                                ? const Color.fromARGB(255, 196, 8, 39)
                                : const Color(0xFF2F8F78))
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
      ),
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
  });

  final Color day;
  final Color night;
  final Color recovery;
  final Color off;
  final Color gridLine;

  factory _CalendarColors.fromTheme(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return const _CalendarColors(
        day: Color(0xFF394943),
        night: Color(0xFF263E42),
        recovery: Color(0xFF383A43),
        off: Color(0xFF202327),
        gridLine: Color(0xFF34383D),
      );
    }

    return const _CalendarColors(
      day: Color(0xFFDCEBE4),
      night: Color(0xFFD5E4E6),
      recovery: Color(0xFFE3E2E8),
      off: Color(0xFFF3F4F3),
      gridLine: Color(0xFFD4D8D6),
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

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
