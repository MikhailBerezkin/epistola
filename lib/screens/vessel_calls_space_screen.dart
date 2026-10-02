import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/models/shift_cycle.dart';
import '../services/spaces/calendar/shift_schedule_calculator.dart';
import '../services/work_schedule/user_assigned_crew_reader.dart';
import '../services/spaces/vessel_calls/vessel_calls_local_cache.dart';
import '../services/spaces/vessel_calls/vessel_calls_month_cache_service.dart';

class VesselCallsSpaceScreen extends StatefulWidget {
  const VesselCallsSpaceScreen({super.key});

  @override
  State<VesselCallsSpaceScreen> createState() => _VesselCallsSpaceScreenState();
}

class _VesselCallsSpaceScreenState extends State<VesselCallsSpaceScreen> {
  static const int _initialPage = 10000;
  static const int _visibleDays = 5;

  static const Color _backgroundColor = Color(0xFF061827);
  static const Color _compactBackgroundColor = Color(0xFF082237);
  static const Color _dayBackgroundColor = Color(0xFF0C2C45);
  static const Color _cardBackgroundColor = Color(0xFF0B263C);

  static const Color _selectedBorderColor = Color(0xFF24A2FF);

  static const Color _containerColor = Color(0xFF279BFF);
  static const Color _bulkColor = Color(0xFFFF962F);
  static const Color _laybyColor = Color(0xFF39B978);

  static const Color _secondaryTextColor = Color(0xFFAFC5D8);

  late final DateTime _anchorDate;
  late final PageController _pageController;
  late final VesselCallsLocalCache _localCache;
  late final VesselCallsMonthCacheService _monthCacheService;
  late final Map<String, _PreviewVessel> _previewVesselsByImo;

  List<_PreviewVesselCall> _calls = const <_PreviewVesselCall>[];

  late DateTime _selectedDate;
  late DateTime _now;

  Timer? _clockTimer;
  late final UserAssignedCrewReader _assignedCrewReader;

  StreamSubscription<ShiftCrew?>? _assignedCrewSubscription;

  ShiftCrew? _assignedCrew;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _anchorDate = DateTime(now.year, now.month, now.day);

    _selectedDate = _anchorDate;
    _now = now;

    _pageController = PageController(initialPage: _initialPage);

    _assignedCrewReader = UserAssignedCrewReader.firebase();

    _watchAssignedCrew();

    _localCache = VesselCallsLocalCache();

    _monthCacheService = VesselCallsMonthCacheService.firebase(
      localCache: _localCache,
    );

    final previewCalls = _buildPreviewCalls(_anchorDate);

    _previewVesselsByImo = <String, _PreviewVessel>{
      for (final call in previewCalls) call.vessel.imo: call.vessel,
    };

    _calls = previewCalls;

    unawaited(_loadCurrentMonthFromCache());

    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _assignedCrewSubscription?.cancel();
    _pageController.dispose();

    super.dispose();
  }

  String get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  }

  void _watchAssignedCrew() {
    final userId = _currentUserId;

    if (userId.isEmpty) {
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
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            // Ошибка чтения звена не должна ломать Судозаходы.
          },
        );
  }

  DateTime _centerDateForPage(int page) {
    return _anchorDate.add(Duration(days: page - _initialPage));
  }

  DateTime _windowStartForPage(int page) {
    return _centerDateForPage(
      page,
    ).subtract(const Duration(days: _visibleDays ~/ 2));
  }

  int _pageForDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);

    return _initialPage + normalized.difference(_anchorDate).inDays;
  }

  Future<void> _loadCurrentMonthFromCache() async {
    final year = _anchorDate.year;
    final month = _anchorDate.month;

    try {
      final cachedMonth = await _localCache.readMonth(year: year, month: month);

      if (cachedMonth == null) {
        await _localCache.writeMonth(_createCachedMonthFromPreview(_calls));

        return;
      }

      final restoredCalls =
          cachedMonth.calls.map(_previewCallFromCached).toList()
            ..sort((left, right) => left.berthFrom.compareTo(right.berthFrom));

      if (!mounted) {
        return;
      }

      setState(() {
        _calls = restoredCalls;
      });
    } catch (_) {
      // Ошибка локального кэша не должна ломать экран.
      // В этом случае остаются встроенные preview-данные.
    }
  }

  CachedVesselMonth _createCachedMonthFromPreview(
    List<_PreviewVesselCall> calls,
  ) {
    final now = DateTime.now();

    DateTime? publishedUntil;

    for (final call in calls) {
      if (publishedUntil == null || call.berthTo.isAfter(publishedUntil)) {
        publishedUntil = call.berthTo;
      }
    }

    return CachedVesselMonth(
      year: _anchorDate.year,
      month: _anchorDate.month,
      revision: 0,
      publishedUntil: publishedUntil,
      calls: calls
          .map(
            (call) => CachedVesselCall(
              id: 'preview-${call.vessel.imo}',
              vesselImo: call.vessel.imo,
              vesselName: call.vessel.name,
              vesselType: call.vesselType.name,
              operationKind: call.operationKind.name,
              lane: call.lane,
              berthFrom: call.berthFrom,
              berthTo: call.berthTo,
              updatedAt: now,
              source: VesselCallCacheSource.monthlySnapshot,
            ),
          )
          .toList(),
      sourceUpdatedAt: now,
      locallyUpdatedAt: now,
      isArchived: false,
    );
  }

  _PreviewVesselCall _previewCallFromCached(CachedVesselCall cached) {
    final vessel =
        _previewVesselsByImo[cached.vesselImo] ??
        _PreviewVessel(
          name: cached.vesselName,
          imo: cached.vesselImo,
          mmsi: '',
          typeLabel: _typeLabelForCached(cached.vesselType),
          lengthMeters: null,
          widthMeters: null,
          deadweightTons: null,
          capacityLabel: null,
        );

    final vesselType = _VesselType.values.firstWhere(
      (value) => value.name == cached.vesselType,
      orElse: () => _VesselType.other,
    );

    final operationKind = _VesselOperationKind.values.firstWhere(
      (value) => value.name == cached.operationKind,
      orElse: () => _VesselOperationKind.cargo,
    );

    return _PreviewVesselCall(
      vessel: vessel,
      vesselType: vesselType,
      operationKind: operationKind,
      lane: cached.lane,
      berthFrom: cached.berthFrom,
      berthTo: cached.berthTo,
    );
  }

  String _typeLabelForCached(String vesselType) {
    return switch (vesselType) {
      'container' => 'Контейнеровоз',
      'bulk' => 'Балкер',
      'service' => 'Служебное судно',
      _ => 'Судно',
    };
  }

  List<_PreviewVesselCall> _buildPreviewCalls(DateTime base) {
    return [
      _PreviewVesselCall(
        vessel: const _PreviewVessel(
          name: 'TEST CONTAINER 01',
          imo: '0000001',
          mmsi: '000000001',
          typeLabel: 'Контейнеровоз',
          lengthMeters: 169,
          widthMeters: 27,
          deadweightTons: 23554,
          capacityLabel: '1 730 TEU',
        ),
        vesselType: _VesselType.container,
        operationKind: _VesselOperationKind.cargo,
        lane: 0,
        berthFrom: DateTime(base.year, base.month, base.day - 1, 8),
        berthTo: DateTime(base.year, base.month, base.day + 1, 20),
      ),
      _PreviewVesselCall(
        vessel: const _PreviewVessel(
          name: 'TEST BULKER 01',
          imo: '0000002',
          mmsi: '000000002',
          typeLabel: 'Балкер',
          lengthMeters: 180,
          widthMeters: 30,
          deadweightTons: 32000,
          capacityLabel: null,
        ),
        vesselType: _VesselType.bulk,
        operationKind: _VesselOperationKind.cargo,
        lane: 3,
        berthFrom: DateTime(base.year, base.month, base.day, 4),
        berthTo: DateTime(base.year, base.month, base.day + 1, 16),
      ),
      _PreviewVesselCall(
        vessel: const _PreviewVessel(
          name: 'TEST CONTAINER 02',
          imo: '0000003',
          mmsi: '000000003',
          typeLabel: 'Контейнеровоз',
          lengthMeters: 155,
          widthMeters: 25,
          deadweightTons: 19000,
          capacityLabel: '1 400 TEU',
        ),
        vesselType: _VesselType.container,
        operationKind: _VesselOperationKind.cargo,
        lane: 1,
        berthFrom: DateTime(base.year, base.month, base.day + 1, 10),
        berthTo: DateTime(base.year, base.month, base.day + 2, 23),
      ),
      _PreviewVesselCall(
        vessel: const _PreviewVessel(
          name: 'TEST SERVICE 01',
          imo: '0000004',
          mmsi: '000000004',
          typeLabel: 'Служебное судно',
          lengthMeters: 115,
          widthMeters: 21,
          deadweightTons: null,
          capacityLabel: null,
        ),
        vesselType: _VesselType.service,
        operationKind: _VesselOperationKind.layby,
        lane: 3,
        berthFrom: DateTime(base.year, base.month, base.day + 1, 17),
        berthTo: DateTime(base.year, base.month, base.day + 2, 12),
      ),
      _PreviewVesselCall(
        vessel: const _PreviewVessel(
          name: 'TEST CONTAINER 03',
          imo: '0000005',
          mmsi: '000000005',
          typeLabel: 'Контейнеровоз',
          lengthMeters: 175,
          widthMeters: 28,
          deadweightTons: 25000,
          capacityLabel: '1 900 TEU',
        ),
        vesselType: _VesselType.container,
        operationKind: _VesselOperationKind.cargo,
        lane: 2,
        berthFrom: DateTime(base.year, base.month, base.day + 3, 6),
        berthTo: DateTime(base.year, base.month, base.day + 4, 18),
      ),
    ];
  }

  List<_PreviewVesselCall> _callsForDay(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);

    final dayEnd = dayStart.add(const Duration(days: 1));

    final result = _calls.where((call) {
      return call.berthFrom.isBefore(dayEnd) && call.berthTo.isAfter(dayStart);
    }).toList();

    result.sort((left, right) => left.berthFrom.compareTo(right.berthFrom));

    return result;
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
  }

  void _handlePageChanged(int page) {
    _selectDate(_centerDateForPage(page));
  }

  Future<List<_PreviewVesselCall>> _loadMonthCallsFromCache(
    DateTime month,
  ) async {
    final isCurrentMonth =
        month.year == _anchorDate.year && month.month == _anchorDate.month;

    final cachedMonth = isCurrentMonth
        ? await _monthCacheService.readLocalMonth(
            year: month.year,
            month: month.month,
          )
        : await _monthCacheService.loadArchivedMonth(
            year: month.year,
            month: month.month,
          );

    if (cachedMonth == null) {
      return const <_PreviewVesselCall>[];
    }

    final calls = cachedMonth.calls.map(_previewCallFromCached).toList()
      ..sort((left, right) => left.berthFrom.compareTo(right.berthFrom));

    return calls;
  }

  Future<void> _refreshCurrentMonthBeforeFullCalendar() async {
    try {
      final result = await _monthCacheService.refreshCurrentMonthIfDue(
        year: _anchorDate.year,
        month: _anchorDate.month,
      );

      if (result != VesselCallsCurrentMonthRefreshResult.rebuilt) {
        return;
      }

      final refreshedMonth = await _monthCacheService.readLocalMonth(
        year: _anchorDate.year,
        month: _anchorDate.month,
      );

      if (refreshedMonth == null || !mounted) {
        return;
      }

      final refreshedCalls =
          refreshedMonth.calls.map(_previewCallFromCached).toList()
            ..sort((left, right) => left.berthFrom.compareTo(right.berthFrom));

      setState(() {
        _calls = refreshedCalls;
      });
    } catch (_) {
      // Ошибка freshness-проверки не должна
      // мешать открытию локального календаря.
    }
  }

  Future<void> _openFullCalendar() async {
    await _refreshCurrentMonthBeforeFullCalendar();

    if (!mounted) {
      return;
    }

    final selectedDate = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute<DateTime>(
        builder: (_) {
          return _VesselCallsMonthScreen(
            initialDate: _selectedDate,
            initialCalls: _calls,
            monthCallsLoader: _loadMonthCallsFromCache,
            today: _anchorDate,
            assignedCrew: _assignedCrew,
            backgroundColor: _backgroundColor,
            dayBackgroundColor: _dayBackgroundColor,
            todayColor: _selectedBorderColor,
            containerColor: _containerColor,
            bulkColor: _bulkColor,
            laybyColor: _laybyColor,
            secondaryTextColor: _secondaryTextColor,
          );
        },
      ),
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    _selectDate(selectedDate);

    final targetPage = _pageForDate(selectedDate);

    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showMarineTrafficPreview(_PreviewVesselCall call) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Позже здесь откроется MarineTraffic '
            'для ${call.vessel.name}.',
          ),
        ),
      );
  }

  void _openVesselCard(_PreviewVessel vessel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBackgroundColor,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 168,
                    height: 112,
                    decoration: BoxDecoration(
                      color: _dayBackgroundColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.directions_boat_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  vessel.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vessel.typeLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _secondaryTextColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                _VesselFact(label: 'IMO', value: vessel.imo),
                _VesselFact(label: 'MMSI', value: vessel.mmsi),
                if (vessel.lengthMeters != null)
                  _VesselFact(
                    label: 'Длина',
                    value: '${vessel.lengthMeters} м',
                  ),
                if (vessel.widthMeters != null)
                  _VesselFact(
                    label: 'Ширина',
                    value: '${vessel.widthMeters} м',
                  ),
                if (vessel.deadweightTons != null)
                  _VesselFact(
                    label: 'DWT',
                    value: '${vessel.deadweightTons} т',
                  ),
                if (vessel.capacityLabel != null)
                  _VesselFact(
                    label: 'Вместимость',
                    value: vessel.capacityLabel!,
                  ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();

                    final call = _calls.firstWhere(
                      (item) => identical(item.vessel, vessel),
                    );

                    _showMarineTrafficPreview(call);
                  },
                  icon: const Icon(Icons.location_searching_rounded),
                  label: const Text('Где судно (MarineTraffic)'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCalls = _callsForDay(_selectedDate);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        title: const Text('Судозаходы'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;

                if (velocity > 250) {
                  unawaited(_openFullCalendar());
                }
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                decoration: BoxDecoration(
                  color: _compactBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SizedBox(
                  height: 104,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (context, page) {
                      final windowStart = _windowStartForPage(page);

                      return _FiveDayVesselStrip(
                        windowStart: windowStart,
                        selectedDate: _selectedDate,
                        calls: _calls,
                        onDateSelected: _selectDate,
                        containerColor: _containerColor,
                        bulkColor: _bulkColor,
                        laybyColor: _laybyColor,
                        selectedBorderColor: _selectedBorderColor,
                        dayBackgroundColor: _dayBackgroundColor,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDayHeading(_selectedDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${selectedCalls.length} '
                    '${_vesselCountWord(selectedCalls.length)}',
                    style: const TextStyle(
                      color: _secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selectedCalls.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    'На этот день судов у причала нет',
                    style: TextStyle(color: _secondaryTextColor, fontSize: 16),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverList.builder(
                itemCount: selectedCalls.length,
                itemBuilder: (context, index) {
                  final call = selectedCalls[index];

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == selectedCalls.length - 1 ? 0 : 10,
                    ),
                    child: _VesselCallCard(
                      call: call,
                      color: _vesselCallColor(
                        call,
                        containerColor: _containerColor,
                        bulkColor: _bulkColor,
                        laybyColor: _laybyColor,
                      ),
                      now: _now,
                      onPhotoTap: () {
                        _openVesselCard(call.vessel);
                      },
                      onMarineTrafficTap: () {
                        _showMarineTrafficPreview(call);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDayHeading(DateTime date) {
    const months = [
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

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  static String _vesselCountWord(int count) {
    final lastTwo = count % 100;
    final last = count % 10;

    if (lastTwo >= 11 && lastTwo <= 14) {
      return 'судов';
    }

    if (last == 1) {
      return 'судно';
    }

    if (last >= 2 && last <= 4) {
      return 'судна';
    }

    return 'судов';
  }
}

class _FiveDayVesselStrip extends StatelessWidget {
  const _FiveDayVesselStrip({
    required this.windowStart,
    required this.selectedDate,
    required this.calls,
    required this.onDateSelected,
    required this.containerColor,
    required this.bulkColor,
    required this.laybyColor,
    required this.selectedBorderColor,
    required this.dayBackgroundColor,
  });

  final DateTime windowStart;
  final DateTime selectedDate;
  final List<_PreviewVesselCall> calls;

  final ValueChanged<DateTime> onDateSelected;

  final Color containerColor;
  final Color bulkColor;
  final Color laybyColor;
  final Color selectedBorderColor;
  final Color dayBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 5;

        return Stack(
          children: [
            Row(
              children: List.generate(5, (index) {
                final date = windowStart.add(Duration(days: index));

                final selected = _isSameDay(date, selectedDate);

                return SizedBox(
                  width: cellWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: dayBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          onDateSelected(date);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? selectedBorderColor
                                  : Colors.white.withValues(alpha: 0.10),
                              width: selected ? 2.2 : 0.8,
                            ),
                          ),
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: [
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: selected ? 21 : 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _shortMonth(date.month),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.60),
                                  fontSize: 10,
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
              }),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _VesselTimelinePainter(
                    windowStart: windowStart,
                    calls: calls,
                    containerColor: containerColor,
                    bulkColor: bulkColor,
                    laybyColor: laybyColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _shortMonth(int month) {
    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];

    return months[month - 1];
  }
}

class _VesselTimelinePainter extends CustomPainter {
  const _VesselTimelinePainter({
    required this.windowStart,
    required this.calls,
    required this.containerColor,
    required this.bulkColor,
    required this.laybyColor,
  });

  final DateTime windowStart;
  final List<_PreviewVesselCall> calls;

  final Color containerColor;
  final Color bulkColor;
  final Color laybyColor;

  static const double _timelineTop = 58;
  static const double _laneStep = 10;
  static const double _strokeWidth = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final windowEnd = windowStart.add(const Duration(days: 5));

    final totalSeconds = windowEnd.difference(windowStart).inSeconds.toDouble();

    for (final call in calls) {
      if (!call.berthFrom.isBefore(windowEnd) ||
          !call.berthTo.isAfter(windowStart)) {
        continue;
      }

      final clippedStart = call.berthFrom.isBefore(windowStart)
          ? windowStart
          : call.berthFrom;

      final clippedEnd = call.berthTo.isAfter(windowEnd)
          ? windowEnd
          : call.berthTo;

      final startSeconds = clippedStart.difference(windowStart).inSeconds;
      final endSeconds = clippedEnd.difference(windowStart).inSeconds;

      final startX = size.width * startSeconds / totalSeconds;
      final endX = size.width * endSeconds / totalSeconds;

      final y = _timelineTop + call.lane * _laneStep;

      final color = _vesselCallColor(
        call,
        containerColor: containerColor,
        bulkColor: bulkColor,
        laybyColor: laybyColor,
      );

      final paint = Paint()
        ..color = color
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(startX, y),
        Offset(math.max(startX + 1, endX), y),
        paint,
      );

      if (_hasTransitionAtStart(call, calls)) {
        _drawTransitionMarker(
          canvas: canvas,
          position: Offset(startX, y),
          color: color,
          strokeWidth: _strokeWidth,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VesselTimelinePainter oldDelegate) {
    return oldDelegate.windowStart != windowStart ||
        oldDelegate.calls != calls ||
        oldDelegate.containerColor != containerColor ||
        oldDelegate.bulkColor != bulkColor ||
        oldDelegate.laybyColor != laybyColor;
  }
}

class _VesselCallsMonthScreen extends StatefulWidget {
  const _VesselCallsMonthScreen({
    required this.initialDate,
    required this.initialCalls,
    required this.monthCallsLoader,
    required this.today,
    required this.assignedCrew,
    required this.backgroundColor,
    required this.dayBackgroundColor,
    required this.todayColor,
    required this.containerColor,
    required this.bulkColor,
    required this.laybyColor,
    required this.secondaryTextColor,
  });

  final DateTime initialDate;
  final List<_PreviewVesselCall> initialCalls;

  final Future<List<_PreviewVesselCall>> Function(DateTime month)
  monthCallsLoader;
  final DateTime today;
  final ShiftCrew? assignedCrew;

  final Color backgroundColor;
  final Color dayBackgroundColor;
  final Color todayColor;

  final Color containerColor;
  final Color bulkColor;
  final Color laybyColor;

  final Color secondaryTextColor;

  @override
  State<_VesselCallsMonthScreen> createState() =>
      _VesselCallsMonthScreenState();
}

class _VesselCallsMonthScreenState extends State<_VesselCallsMonthScreen> {
  static const int _historyPageCount = 1200;

  static const _weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  late final DateTime _maxVisibleMonth;
  late final DateTime _firstVisibleMonth;
  late final PageController _monthPageController;

  late int _currentPage;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();

    _maxVisibleMonth = _calculateMaxVisibleMonth();

    _firstVisibleMonth = DateTime(
      _maxVisibleMonth.year,
      _maxVisibleMonth.month - _historyPageCount,
    );

    final initialMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
    );

    final clampedInitialMonth = initialMonth.isAfter(_maxVisibleMonth)
        ? _maxVisibleMonth
        : initialMonth;

    _currentPage = _pageForMonth(clampedInitialMonth);

    _visibleMonth = _monthForPage(_currentPage);

    _monthPageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _monthPageController.dispose();

    super.dispose();
  }

  DateTime _calculateMaxVisibleMonth() {
    if (widget.initialCalls.isEmpty) {
      return DateTime(widget.today.year, widget.today.month);
    }

    var latest = widget.initialCalls.first.berthTo;

    for (final call in widget.initialCalls.skip(1)) {
      if (call.berthTo.isAfter(latest)) {
        latest = call.berthTo;
      }
    }

    final latestMonth = DateTime(latest.year, latest.month);

    final todayMonth = DateTime(widget.today.year, widget.today.month);

    if (latestMonth.isBefore(todayMonth)) {
      return todayMonth;
    }

    return latestMonth;
  }

  int _pageForMonth(DateTime month) {
    return (month.year - _firstVisibleMonth.year) * 12 +
        month.month -
        _firstVisibleMonth.month;
  }

  DateTime _monthForPage(int page) {
    return DateTime(_firstVisibleMonth.year, _firstVisibleMonth.month + page);
  }

  bool get _canGoForward {
    return _currentPage < _historyPageCount;
  }

  void _goToPreviousMonth() {
    if (_currentPage <= 0) {
      return;
    }

    _monthPageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToNextMonth() {
    if (!_canGoForward) {
      return;
    }

    _monthPageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleMonthPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _visibleMonth = _monthForPage(page);
    });
  }

  void _selectDate(DateTime date) {
    Navigator.of(context).pop(DateTime(date.year, date.month, date.day));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.backgroundColor,
        foregroundColor: Colors.white,
        title: Text(_formatMonthTitle(_visibleMonth)),
        actions: [
          IconButton(
            tooltip: 'Предыдущий месяц',
            onPressed: _currentPage > 0 ? _goToPreviousMonth : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Следующий месяц',
            onPressed: _canGoForward ? _goToNextMonth : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Row(
                children: [
                  for (final weekday in _weekdays)
                    Expanded(
                      child: Center(
                        child: Text(
                          weekday,
                          style: TextStyle(
                            color: widget.secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _monthPageController,
                itemCount: _historyPageCount + 1,
                onPageChanged: _handleMonthPageChanged,
                itemBuilder: (context, page) {
                  final month = _monthForPage(page);

                  return _CachedVesselMonthView(
                    visibleMonth: month,
                    initialMonth: DateTime(
                      widget.initialDate.year,
                      widget.initialDate.month,
                    ),
                    initialCalls: widget.initialCalls,
                    monthCallsLoader: widget.monthCallsLoader,
                    today: widget.today,
                    assignedCrew: widget.assignedCrew,
                    backgroundColor: widget.dayBackgroundColor,
                    todayColor: widget.todayColor,
                    containerColor: widget.containerColor,
                    bulkColor: widget.bulkColor,
                    laybyColor: widget.laybyColor,
                    onDateSelected: _selectDate,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatMonthTitle(DateTime date) {
    const months = [
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

    return '${months[date.month - 1]} '
        '${date.year}';
  }
}

class _CachedVesselMonthView extends StatefulWidget {
  const _CachedVesselMonthView({
    required this.visibleMonth,
    required this.initialMonth,
    required this.initialCalls,
    required this.monthCallsLoader,
    required this.today,
    required this.assignedCrew,
    required this.backgroundColor,
    required this.todayColor,
    required this.containerColor,
    required this.bulkColor,
    required this.laybyColor,
    required this.onDateSelected,
  });

  final DateTime visibleMonth;
  final DateTime initialMonth;

  final List<_PreviewVesselCall> initialCalls;

  final Future<List<_PreviewVesselCall>> Function(DateTime month)
  monthCallsLoader;

  final DateTime today;
  final ShiftCrew? assignedCrew;

  final Color backgroundColor;
  final Color todayColor;

  final Color containerColor;
  final Color bulkColor;
  final Color laybyColor;

  final ValueChanged<DateTime> onDateSelected;

  @override
  State<_CachedVesselMonthView> createState() => _CachedVesselMonthViewState();
}

class _CachedVesselMonthViewState extends State<_CachedVesselMonthView> {
  late final Future<List<_PreviewVesselCall>> _callsFuture;

  @override
  void initState() {
    super.initState();

    if (_isSameMonth(widget.visibleMonth, widget.initialMonth)) {
      _callsFuture = Future<List<_PreviewVesselCall>>.value(
        widget.initialCalls,
      );
    } else {
      _callsFuture = widget.monthCallsLoader(widget.visibleMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_PreviewVesselCall>>(
      future: _callsFuture,
      builder: (context, snapshot) {
        final calls = snapshot.data ?? const <_PreviewVesselCall>[];

        return _VesselMonthView(
          visibleMonth: widget.visibleMonth,
          calls: calls,
          today: widget.today,
          assignedCrew: widget.assignedCrew,
          backgroundColor: widget.backgroundColor,
          todayColor: widget.todayColor,
          containerColor: widget.containerColor,
          bulkColor: widget.bulkColor,
          laybyColor: widget.laybyColor,
          onDateSelected: widget.onDateSelected,
        );
      },
    );
  }
}

class _VesselMonthView extends StatelessWidget {
  const _VesselMonthView({
    required this.visibleMonth,
    required this.calls,
    required this.today,
    required this.assignedCrew,
    required this.backgroundColor,
    required this.todayColor,
    required this.containerColor,
    required this.bulkColor,
    required this.laybyColor,
    required this.onDateSelected,
  });

  final DateTime visibleMonth;
  final List<_PreviewVesselCall> calls;
  final DateTime today;
  final ShiftCrew? assignedCrew;

  final Color backgroundColor;
  final Color todayColor;

  final Color containerColor;
  final Color bulkColor;
  final Color laybyColor;

  final ValueChanged<DateTime> onDateSelected;

  DateTime _gridStart() {
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);

    return firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final gridStart = _gridStart();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Column(
        children: List.generate(6, (weekIndex) {
          final weekStart = gridStart.add(Duration(days: weekIndex * 7));

          return Expanded(
            child: _VesselMonthWeekRow(
              weekStart: weekStart,
              visibleMonth: visibleMonth,
              today: today,
              assignedCrew: assignedCrew,
              calls: calls,
              backgroundColor: backgroundColor,
              todayColor: todayColor,
              containerColor: containerColor,
              bulkColor: bulkColor,
              laybyColor: laybyColor,
              onDateSelected: onDateSelected,
            ),
          );
        }),
      ),
    );
  }
}

class _VesselMonthWeekRow extends StatelessWidget {
  const _VesselMonthWeekRow({
    required this.weekStart,
    required this.visibleMonth,
    required this.today,
    required this.assignedCrew,
    required this.calls,
    required this.backgroundColor,
    required this.todayColor,
    required this.containerColor,
    required this.bulkColor,
    required this.laybyColor,
    required this.onDateSelected,
  });

  final DateTime weekStart;
  final DateTime visibleMonth;
  final DateTime today;
  final ShiftCrew? assignedCrew;

  final List<_PreviewVesselCall> calls;

  final Color backgroundColor;
  final Color todayColor;
  final Color containerColor;
  final Color bulkColor;
  final Color laybyColor;

  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;

        return Stack(
          children: [
            Row(
              children: List.generate(7, (dayIndex) {
                final date = weekStart.add(Duration(days: dayIndex));

                final isCurrentMonth =
                    date.year == visibleMonth.year &&
                    date.month == visibleMonth.month;

                final isToday = _isSameDay(date, today);

                final phase = assignedCrew == null
                    ? null
                    : const ShiftScheduleCalculator().phaseFor(
                        date: date,
                        crew: assignedCrew!,
                      );

                final shiftBorderColor = switch (phase) {
                  ShiftCyclePhase.day1 ||
                  ShiftCyclePhase.day2 => const Color(0xFF78736C),

                  ShiftCyclePhase.night1 ||
                  ShiftCyclePhase.night2 => const Color(0xFF6866A8),

                  _ => null,
                };

                return SizedBox(
                  width: cellWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(1.2),
                    child: Material(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          onDateSelected(date);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  shiftBorderColor ??
                                  Colors.white.withValues(alpha: 0.08),
                              width: shiftBorderColor == null ? 0.7 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(5, 4, 4, 4),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: _MonthDayNumber(
                              date: date,
                              isCurrentMonth: isCurrentMonth,
                              isToday: isToday,
                              todayColor: todayColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _VesselMonthWeekPainter(
                    weekStart: weekStart,
                    calls: calls,
                    containerColor: containerColor,
                    bulkColor: bulkColor,
                    laybyColor: laybyColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthDayNumber extends StatelessWidget {
  const _MonthDayNumber({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.todayColor,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final Color todayColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${date.day}',
      style: TextStyle(
        color: isToday
            ? todayColor
            : Colors.white.withValues(alpha: isCurrentMonth ? 1 : 0.30),
        fontSize: 13,
        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

class _VesselMonthWeekPainter extends CustomPainter {
  const _VesselMonthWeekPainter({
    required this.weekStart,
    required this.calls,
    required this.containerColor,
    required this.bulkColor,
    required this.laybyColor,
  });

  final DateTime weekStart;

  final List<_PreviewVesselCall> calls;

  final Color containerColor;
  final Color bulkColor;
  final Color laybyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final weekEnd = weekStart.add(const Duration(days: 7));

    final totalSeconds = weekEnd.difference(weekStart).inSeconds.toDouble();

    final timelineTop = math.min(31.0, size.height * 0.38);

    final timelineHeight = math.max(20.0, size.height - timelineTop - 6);

    final laneHeight = timelineHeight / 4;

    final strokeWidth = math.min(4.8, laneHeight * 0.48);

    for (final call in calls) {
      if (!call.berthFrom.isBefore(weekEnd) ||
          !call.berthTo.isAfter(weekStart)) {
        continue;
      }

      final clippedStart = call.berthFrom.isBefore(weekStart)
          ? weekStart
          : call.berthFrom;

      final clippedEnd = call.berthTo.isAfter(weekEnd) ? weekEnd : call.berthTo;

      final startSeconds = clippedStart.difference(weekStart).inSeconds;
      final endSeconds = clippedEnd.difference(weekStart).inSeconds;

      final startX = size.width * startSeconds / totalSeconds;
      final endX = size.width * endSeconds / totalSeconds;

      final y = timelineTop + laneHeight * (call.lane + 0.5);

      final color = _vesselCallColor(
        call,
        containerColor: containerColor,
        bulkColor: bulkColor,
        laybyColor: laybyColor,
      );

      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(startX, y),
        Offset(math.max(startX + 1, endX), y),
        paint,
      );

      if (_hasTransitionAtStart(call, calls) &&
          !call.berthFrom.isBefore(weekStart) &&
          call.berthFrom.isBefore(weekEnd)) {
        _drawTransitionMarker(
          canvas: canvas,
          position: Offset(startX, y),
          color: color,
          strokeWidth: strokeWidth,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VesselMonthWeekPainter oldDelegate) {
    return oldDelegate.weekStart != weekStart ||
        oldDelegate.calls != calls ||
        oldDelegate.containerColor != containerColor ||
        oldDelegate.bulkColor != bulkColor ||
        oldDelegate.laybyColor != laybyColor;
  }
}

class _VesselCallCard extends StatelessWidget {
  const _VesselCallCard({
    required this.call,
    required this.color,
    required this.now,
    required this.onPhotoTap,
    required this.onMarineTrafficTap,
  });

  final _PreviewVesselCall call;

  final Color color;
  final DateTime now;

  final VoidCallback onPhotoTap;
  final VoidCallback onMarineTrafficTap;

  @override
  Widget build(BuildContext context) {
    final duration = call.berthTo.difference(call.berthFrom);

    final totalHours = duration.inMinutes / 60;

    final shifts = totalHours / 12;

    final isUpcoming = now.isBefore(call.berthFrom);

    final isFinished = !now.isBefore(call.berthTo);

    final isActive = !isUpcoming && !isFinished;

    final remainingToBerth = call.berthFrom.difference(now);

    final remainingToDeparture = call.berthTo.difference(now);

    final totalMinutes = duration.inMinutes;

    final elapsedMinutes = now.difference(call.berthFrom).inMinutes;

    final progress = totalMinutes <= 0
        ? 0.0
        : (elapsedMinutes / totalMinutes).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: _VesselCallsSpaceScreenState._cardBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPhotoTap,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.directions_boat_rounded,
                size: 48,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.vessel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 4,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        call.vessel.typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:
                              _VesselCallsSpaceScreenState._secondaryTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (call.operationKind == _VesselOperationKind.layby) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Отстой',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${_formatDateTime(call.berthFrom)}'
                  '  →  '
                  '${_formatDateTime(call.berthTo)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Стоянка: '
                  '${_formatHours(totalHours)} · '
                  '${_formatShifts(shifts)}',
                  style: const TextStyle(
                    color: _VesselCallsSpaceScreenState._secondaryTextColor,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 7),
                if (isUpcoming)
                  Text(
                    'До постановки: '
                    '${_formatRemaining(remainingToBerth)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (isActive) ...[
                  Text(
                    'До отхода: '
                    '${_formatRemaining(remainingToDeparture)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
                if (isFinished)
                  Text(
                    'Закончено · отход '
                    '${_formatDateTime(call.berthTo)}',
                    style: const TextStyle(
                      color: _VesselCallsSpaceScreenState._secondaryTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: onMarineTrafficTap,
                  icon: const Icon(Icons.location_searching_rounded, size: 18),
                  label: const Text('Где судно'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');

    final minute = date.minute.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$hour:$minute '
        '$day.$month';
  }

  static String _formatHours(double hours) {
    if (hours == hours.roundToDouble()) {
      return '${hours.round()} ч';
    }

    return '${hours.toStringAsFixed(1)} ч';
  }

  static String _formatShifts(double shifts) {
    if ((shifts - shifts.round()).abs() < 0.05) {
      return '${shifts.round()} смен';
    }

    return '${shifts.toStringAsFixed(1)} смены';
  }

  static String _formatRemaining(Duration duration) {
    if (duration <= Duration.zero) {
      return '0 мин';
    }

    final totalMinutes = duration.inMinutes;

    final days = totalMinutes ~/ (24 * 60);

    final hours = (totalMinutes % (24 * 60)) ~/ 60;

    final minutes = totalMinutes % 60;

    final parts = <String>[];

    if (days > 0) {
      parts.add('$days д');
    }

    if (hours > 0) {
      parts.add('$hours ч');
    }

    if (days == 0 && minutes > 0) {
      parts.add('$minutes мин');
    }

    return parts.join(' ');
  }
}

class _VesselFact extends StatelessWidget {
  const _VesselFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _VesselCallsSpaceScreenState._secondaryTextColor,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _VesselType { container, bulk, service, other }

enum _VesselOperationKind { cargo, layby }

class _PreviewVessel {
  const _PreviewVessel({
    required this.name,
    required this.imo,
    required this.mmsi,
    required this.typeLabel,
    required this.lengthMeters,
    required this.widthMeters,
    required this.deadweightTons,
    required this.capacityLabel,
  });

  final String name;
  final String imo;
  final String mmsi;
  final String typeLabel;

  final int? lengthMeters;
  final int? widthMeters;
  final int? deadweightTons;

  final String? capacityLabel;
}

class _PreviewVesselCall {
  const _PreviewVesselCall({
    required this.vessel,
    required this.vesselType,
    required this.operationKind,
    required this.lane,
    required this.berthFrom,
    required this.berthTo,
  });

  final _PreviewVessel vessel;

  final _VesselType vesselType;
  final _VesselOperationKind operationKind;

  /// Временная визуальная дорожка 0..3.
  ///
  /// Пока НЕ означает конкретный причал.
  final int lane;

  final DateTime berthFrom;
  final DateTime berthTo;
}

Color _vesselCallColor(
  _PreviewVesselCall call, {
  required Color containerColor,
  required Color bulkColor,
  required Color laybyColor,
}) {
  if (call.operationKind == _VesselOperationKind.layby) {
    return laybyColor;
  }

  return switch (call.vesselType) {
    _VesselType.container => containerColor,
    _VesselType.bulk => bulkColor,
    _VesselType.service => laybyColor,
    _VesselType.other => laybyColor,
  };
}

bool _hasTransitionAtStart(
  _PreviewVesselCall call,
  List<_PreviewVesselCall> calls,
) {
  const transitionTolerance = Duration(hours: 2);

  for (final other in calls) {
    if (identical(other, call) || other.lane != call.lane) {
      continue;
    }

    final difference = call.berthFrom.difference(other.berthTo);

    if (!difference.isNegative && difference <= transitionTolerance) {
      return true;
    }
  }

  return false;
}

void _drawTransitionMarker({
  required Canvas canvas,
  required Offset position,
  required Color color,
  required double strokeWidth,
}) {
  final outerPaint = Paint()..color = Colors.white;

  canvas.drawCircle(position, strokeWidth * 0.72, outerPaint);

  final innerPaint = Paint()..color = color;

  canvas.drawCircle(position, strokeWidth * 0.35, innerPaint);
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}
