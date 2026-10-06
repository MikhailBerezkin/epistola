import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/models/shift_cycle.dart';
import '../services/spaces/calendar/shift_schedule_calculator.dart';
import '../services/work_schedule/user_assigned_crew_reader.dart';
import '../services/spaces/vessel_calls/vessel_calls_local_cache.dart';
import '../services/spaces/vessel_calls/vessel_calls_month_cache_service.dart';
import '../domain/models/vessel_registry.dart';
import '../services/spaces/vessel_calls/vessel_registry_service.dart';
import '../domain/models/spaces_access_role.dart';
import '../services/spaces/spaces_dependencies.dart';
import '../services/spaces/spaces_access_service.dart';
import '../services/spaces/vessel_calls/vessel_photo_url_cache.dart';
import '../widgets/spaces/vessel_calls/vessel_photo_image.dart';
import '../services/spaces/vessel_calls/vessel_photo_preparation_service.dart';
import '../services/spaces/vessel_calls/vessel_photo_processor.dart';
import '../services/spaces/vessel_calls/vessel_photo_replacement_service.dart';
import 'dart:ui' as ui;

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
  static const Color _otherCargoColor = Color(0xFF9B7BFF);
  static const Color _unknownColor = Color(0xFF8193A2);
  static const Color _laybyColor = Color(0xFF39B978);

  static const Color _secondaryTextColor = Color(0xFFAFC5D8);

  late final DateTime _anchorDate;
  late final PageController _pageController;
  late final VesselCallsLocalCache _localCache;
  late final VesselCallsMonthCacheService _monthCacheService;
  late final VesselRegistryService _vesselRegistryService;
  late final SpacesAccessService _spacesAccessService;
  late final VesselPhotoUrlCache _vesselPhotoUrlCache;
  late final VesselPhotoPreparationService _vesselPhotoPreparationService;
  late final VesselPhotoReplacementService _vesselPhotoReplacementService;

  SpacesAccessRole _spacesAccessRole = SpacesAccessRole.member;

  VesselRegistrySnapshot _vesselRegistry = const VesselRegistrySnapshot(
    lines: [],
    vessels: [],
  );

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
    _vesselRegistryService = VesselRegistryService.firebase();

    _vesselPhotoUrlCache = VesselPhotoUrlCache();
    _vesselPhotoPreparationService = VesselPhotoPreparationService();
    _vesselPhotoReplacementService = VesselPhotoReplacementService.firebase();

    _spacesAccessService = defaultSpacesAccessService;
    unawaited(_loadSpacesAccessRole());

    unawaited(_loadRegistryAndRefreshCurrentMonth());

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

  Future<void> _loadRegistryAndRefreshCurrentMonth() async {
    _vesselRegistry = await _vesselRegistryService.load();

    await _loadAndRefreshCurrentMonth();
  }

  Future<void> _loadAndRefreshCurrentMonth() async {
    final year = _anchorDate.year;
    final month = _anchorDate.month;

    try {
      final cachedMonth = await _monthCacheService.readLocalMonth(
        year: year,
        month: month,
      );

      if (cachedMonth != null && mounted) {
        final cachedCalls =
            cachedMonth.calls.map(_previewCallFromCached).toList()..sort(
              (left, right) => left.berthFrom.compareTo(right.berthFrom),
            );

        setState(() {
          _calls = cachedCalls;
        });

        unawaited(_preloadVesselPhotosForDay(_selectedDate));
      }

      final refreshResult = await _monthCacheService.refreshCurrentMonthNow(
        year: year,
        month: month,
      );

      if (refreshResult != VesselCallsCurrentMonthRefreshResult.rebuilt) {
        return;
      }

      final refreshedMonth = await _monthCacheService.readLocalMonth(
        year: year,
        month: month,
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

      unawaited(_preloadVesselPhotosForDay(_selectedDate));
    } catch (_) {
      // Судозаходы должны оставаться доступными даже при временной
      // ошибке локального кэша или Firestore.
    }
  }

  Future<bool> _saveVesselRegistryEntry({
    required _PreviewVessel vessel,
    required VesselPhysicalType physicalType,
    required VesselWorkType workType,
    String? imo,
    double? lengthMeters,
    int? deadweightTons,
    int? teuCapacity,
    String? marineTrafficUrl,
    required bool markVerified,
  }) async {
    final userId = _currentUserId;

    if (userId.isEmpty || !_spacesAccessRole.canManageVesselRegistry) {
      return false;
    }

    final normalizedImo = imo?.trim();

    final latestRegistryEntry = _vesselRegistry
        .resolve(shipName: vessel.name, lineName: vessel.lineName)
        .vessel;

    final existingEntry = latestRegistryEntry ?? vessel.registryEntry;

    final lineNameNormalized = normalizeVesselRegistryText(vessel.lineName);

    VesselLineRegistryEntry? matchedLine;

    for (final line in _vesselRegistry.lines) {
      if (line.normalizedName == lineNameNormalized) {
        matchedLine = line;
        break;
      }
    }

    final existingLineId = existingEntry?.lineId.trim() ?? '';

    final lineId = existingLineId.isNotEmpty
        ? existingLineId
        : matchedLine?.lineId.trim() ?? '';

    if (lineId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Не удалось определить линию судна.')),
          );
      }

      return false;
    }

    final vesselUid = existingEntry?.vesselUid.trim().isNotEmpty == true
        ? existingEntry!.vesselUid.trim()
        : normalizedImo != null && normalizedImo.isNotEmpty
        ? 'imo_$normalizedImo'
        : _buildManualVesselUid(vesselName: vessel.name, lineId: lineId);

    const universalWorkTypes = <VesselWorkType>[
      VesselWorkType.container,
      VesselWorkType.bulk,
      VesselWorkType.special,
      VesselWorkType.other,
    ];

    final resolvedDefaultWorkType =
        existingEntry?.resolvedDefaultWorkType == VesselWorkType.unknown
        ? workType
        : existingEntry?.resolvedDefaultWorkType ?? workType;

    final entry = VesselRegistryEntry(
      vesselUid: vesselUid,
      // Имя от ПКТ сохраняем как исходное имя карточки.
      name: existingEntry?.name.trim().isNotEmpty == true
          ? existingEntry!.name
          : vessel.name,
      lineId: lineId,
      isVerified: markVerified || (existingEntry?.isVerified ?? false),
      physicalType: physicalType,
      defaultWorkType: resolvedDefaultWorkType,
      allowedWorkTypes: universalWorkTypes,

      // Быстрый выбор груза всегда становится текущим
      // фактическим статусом судна.
      workTypeOverride: workType,

      imo: normalizedImo?.isNotEmpty == true
          ? normalizedImo
          : existingEntry?.imo,
      lengthMeters: lengthMeters ?? existingEntry?.lengthMeters,
      deadweightTons: deadweightTons ?? existingEntry?.deadweightTons,
      teuCapacity: teuCapacity ?? existingEntry?.teuCapacity,

      // Фотография относится к судну как к постоянной сущности.
      // Обычное редактирование характеристик не должно
      // изменять, сбрасывать или перевыпускать фото.
      photoPath: existingEntry?.photoPath,
      photoThumbPath: existingEntry?.photoThumbPath,
      photoFullPath: existingEntry?.photoFullPath,
      photoVersion: existingEntry?.photoVersion,

      marineTrafficUrl: marineTrafficUrl ?? existingEntry?.marineTrafficUrl,
      updatedAt: existingEntry?.updatedAt,
      updatedBy: userId,
    );

    try {
      await _vesselRegistryService.saveVessel(vessel: entry, updatedBy: userId);

      final refreshedRegistry = await _vesselRegistryService.load();

      if (!mounted) {
        return true;
      }

      _vesselRegistry = refreshedRegistry;

      await _reloadPreviewCallsFromLocalMonth();

      if (!mounted) {
        return true;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Данные судна сохранены.')),
        );

      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить данные судна.')),
        );

      return false;
    }
  }

  String _buildManualVesselUid({
    required String vesselName,
    required String lineId,
  }) {
    final normalizedName = normalizeVesselRegistryText(vesselName)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    final normalizedLineId = lineId
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    final safeName = normalizedName.isEmpty ? 'unknown' : normalizedName;

    final safeLine = normalizedLineId.isEmpty ? 'unknown' : normalizedLineId;

    return 'manual_${safeLine}_$safeName';
  }

  Future<void> _reloadPreviewCallsFromLocalMonth() async {
    final cachedMonth = await _monthCacheService.readLocalMonth(
      year: _anchorDate.year,
      month: _anchorDate.month,
    );

    if (cachedMonth == null || !mounted) {
      return;
    }

    final refreshedCalls =
        cachedMonth.calls.map(_previewCallFromCached).toList()
          ..sort((left, right) => left.berthFrom.compareTo(right.berthFrom));

    setState(() {
      _calls = refreshedCalls;
    });

    unawaited(_preloadVesselPhotosForDay(_selectedDate));
  }

  _PreviewVesselCall _previewCallFromCached(CachedVesselCall cached) {
    final resolution = _vesselRegistry.resolve(
      shipName: cached.vesselName,
      lineName: cached.lineName,
    );

    final registryVessel = resolution.vessel;

    final vessel = registryVessel == null
        ? _PreviewVessel(
            name: cached.vesselName,
            lineName: cached.lineName,
            imo: '',
            mmsi: '',
            physicalType: VesselPhysicalType.unknown,
            workType: resolution.workType,
            physicalTypeLabel: VesselPhysicalType.unknown.displayName,
            workTypeLabel: resolution.workType.displayName,
            lengthMeters: null,
            widthMeters: null,
            deadweightTons: null,
            capacityLabel: null,
            registryEntry: null,
          )
        : _PreviewVessel(
            // Имя конкретного судозахода всегда берём из ПКТ.
            name: cached.vesselName,
            lineName: cached.lineName,
            imo: registryVessel.imo ?? '',
            mmsi: '',
            physicalType: registryVessel.physicalType,
            workType: registryVessel.effectiveWorkType,
            physicalTypeLabel: registryVessel.physicalType.displayName,
            workTypeLabel: registryVessel.effectiveWorkType.displayName,
            lengthMeters: registryVessel.lengthMeters?.round(),
            widthMeters: null,
            deadweightTons: registryVessel.deadweightTons,
            capacityLabel: registryVessel.teuCapacity == null
                ? null
                : '${registryVessel.teuCapacity} TEU',
            registryEntry: registryVessel,
          );

    final vesselType = switch (resolution.workType) {
      VesselWorkType.container => _VesselType.container,
      VesselWorkType.bulk => _VesselType.bulk,
      VesselWorkType.special => _VesselType.service,
      VesselWorkType.other => _VesselType.other,
      VesselWorkType.unknown => _VesselType.unknown,
    };

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

  Future<void> _loadSpacesAccessRole() async {
    final userId = _currentUserId;

    if (userId.isEmpty) {
      return;
    }

    try {
      final role = await _spacesAccessService.getRole(userId: userId);

      if (!mounted) {
        return;
      }

      setState(() {
        _spacesAccessRole = role;
      });
    } catch (_) {
      // Ошибка чтения роли не должна ломать экран Судозаходов.
    }
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

  Future<void> _preloadVesselPhotosForDay(DateTime date) async {
    final calls = _callsForDay(date);

    final thumbnailPaths = calls
        .take(10)
        .map((call) => call.vessel.registryEntry?.effectivePhotoThumbPath);

    await _vesselPhotoUrlCache.preload(thumbnailPaths, maximumItems: 10);
  }

  void _selectDate(DateTime date) {
    final selectedDate = DateTime(date.year, date.month, date.day);

    setState(() {
      _selectedDate = selectedDate;
    });

    unawaited(_preloadVesselPhotosForDay(selectedDate));
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

  Future<VesselPhysicalType?> _showVesselPhysicalTypePicker({
    required BuildContext context,
    required VesselPhysicalType selectedType,
  }) {
    const types = <VesselPhysicalType>[
      VesselPhysicalType.container,
      VesselPhysicalType.bulk,
      VesselPhysicalType.generalCargo,
      VesselPhysicalType.tanker,
      VesselPhysicalType.icebreaker,
      VesselPhysicalType.tug,
      VesselPhysicalType.reefer,
      VesselPhysicalType.multipurpose,
      VesselPhysicalType.roRo,
      VesselPhysicalType.ferry,
      VesselPhysicalType.other,
      VesselPhysicalType.unknown,
    ];

    return showModalBottomSheet<VesselPhysicalType>(
      context: context,
      backgroundColor: _cardBackgroundColor,
      showDragHandle: true,
      builder: (pickerContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Тип судна',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final type in types)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              type.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: type == selectedType
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                  )
                                : null,
                            onTap: () {
                              Navigator.of(pickerContext).pop(type);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<VesselWorkType?> _showVesselWorkTypePicker({
    required BuildContext context,
    required VesselWorkType selectedType,
  }) {
    const types = <VesselWorkType>[
      VesselWorkType.container,
      VesselWorkType.bulk,
      VesselWorkType.special,
      VesselWorkType.other,
    ];

    return showModalBottomSheet<VesselWorkType>(
      context: context,
      backgroundColor: _cardBackgroundColor,
      showDragHandle: true,
      builder: (pickerContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Тип груза / захода',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                for (final type in types)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _vesselWorkTypeColor(type),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      type.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: type == selectedType
                        ? const Icon(Icons.check_rounded, color: Colors.white)
                        : null,
                    onTap: () {
                      Navigator.of(pickerContext).pop(type);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_VesselSpecialEditResult?> _openSpecialVesselEditor({
    required _PreviewVessel vessel,
    required VesselPhysicalType initialPhysicalType,
    required VesselWorkType initialWorkType,
  }) {
    final latestRegistryEntry = _vesselRegistry
        .resolve(shipName: vessel.name, lineName: vessel.lineName)
        .vessel;

    final currentRegistryEntry = latestRegistryEntry ?? vessel.registryEntry;

    final imoController = TextEditingController(
      text: currentRegistryEntry?.imo ?? vessel.imo,
    );

    final lengthController = TextEditingController(
      text:
          currentRegistryEntry?.lengthMeters?.toString() ??
          vessel.lengthMeters?.toString() ??
          '',
    );

    final deadweightController = TextEditingController(
      text:
          currentRegistryEntry?.deadweightTons?.toString() ??
          vessel.deadweightTons?.toString() ??
          '',
    );

    final teuController = TextEditingController(
      text: currentRegistryEntry?.teuCapacity?.toString() ?? '',
    );

    final marineTrafficController = TextEditingController(
      text: currentRegistryEntry?.marineTrafficUrl ?? '',
    );

    var selectedPhysicalType = initialPhysicalType;
    var selectedWorkType = initialWorkType;

    InputDecoration fieldDecoration(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _secondaryTextColor),
        floatingLabelStyle: const TextStyle(color: _secondaryTextColor),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _selectedBorderColor, width: 1.5),
        ),
        border: const OutlineInputBorder(),
      );
    }

    InputDecoration readOnlyDecoration(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _secondaryTextColor),
        floatingLabelStyle: const TextStyle(color: _secondaryTextColor),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.10),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
        ),
        border: const OutlineInputBorder(),
      );
    }

    return showModalBottomSheet<_VesselSpecialEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBackgroundColor,
      showDragHandle: true,
      builder: (editorContext) {
        return StatefulBuilder(
          builder: (context, setEditorState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 4,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Специальный режим редактирования',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Изменения перезапишут данные судна в реестре.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 22),

                      TextFormField(
                        initialValue: vessel.name,
                        readOnly: true,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: readOnlyDecoration('Имя от ПКТ'),
                      ),
                      const SizedBox(height: 12),

                      if (vessel.lineName.trim().isNotEmpty) ...[
                        TextFormField(
                          initialValue: vessel.lineName,
                          readOnly: true,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: readOnlyDecoration('Линия от ПКТ'),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: imoController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: Colors.white,
                        decoration: fieldDecoration('IMO'),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Тип судна',
                              style: TextStyle(
                                color: _secondaryTextColor,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: _VesselChoiceButton(
                              label:
                                  selectedPhysicalType ==
                                      VesselPhysicalType.unknown
                                  ? 'Выбрать'
                                  : selectedPhysicalType.displayName,
                              onTap: () async {
                                final selected =
                                    await _showVesselPhysicalTypePicker(
                                      context: editorContext,
                                      selectedType: selectedPhysicalType,
                                    );

                                if (selected == null) {
                                  return;
                                }

                                setEditorState(() {
                                  selectedPhysicalType = selected;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Тип груза / захода',
                              style: TextStyle(
                                color: _secondaryTextColor,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: _VesselChoiceButton(
                              label: selectedWorkType == VesselWorkType.unknown
                                  ? 'Выбрать'
                                  : selectedWorkType.displayName,
                              color: selectedWorkType == VesselWorkType.unknown
                                  ? null
                                  : _vesselWorkTypeColor(selectedWorkType),
                              onTap: () async {
                                final selected =
                                    await _showVesselWorkTypePicker(
                                      context: editorContext,
                                      selectedType: selectedWorkType,
                                    );

                                if (selected == null) {
                                  return;
                                }

                                setEditorState(() {
                                  selectedWorkType = selected;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: lengthController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: Colors.white,
                        decoration: fieldDecoration('Длина, м'),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: deadweightController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: Colors.white,
                        decoration: fieldDecoration('DWT, т'),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: teuController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: Colors.white,
                        decoration: fieldDecoration('TEU'),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: marineTrafficController,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: Colors.white,
                        decoration: fieldDecoration('MarineTraffic'),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(editorContext).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  width: 1.3,
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text(
                                'Отмена',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                final normalizedImo = imoController.text.trim();

                                final normalizedMarineTraffic =
                                    marineTrafficController.text.trim();

                                Navigator.of(editorContext).pop(
                                  _VesselSpecialEditResult(
                                    physicalType: selectedPhysicalType,
                                    workType: selectedWorkType,
                                    imo: normalizedImo.isEmpty
                                        ? null
                                        : normalizedImo,
                                    lengthMeters: double.tryParse(
                                      lengthController.text.trim().replaceAll(
                                        ',',
                                        '.',
                                      ),
                                    ),
                                    deadweightTons: int.tryParse(
                                      deadweightController.text.trim(),
                                    ),
                                    teuCapacity: int.tryParse(
                                      teuController.text.trim(),
                                    ),
                                    marineTrafficUrl:
                                        normalizedMarineTraffic.isEmpty
                                        ? null
                                        : normalizedMarineTraffic,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Сохранить'),
                            ),
                          ),
                        ],
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
  }

  Future<PreparedVesselPhotoImages?> _chooseVesselPhoto(
    BuildContext context,
  ) async {
    final source = await showModalBottomSheet<_VesselPhotoSource>(
      context: context,
      backgroundColor: _cardBackgroundColor,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Выбрать из галереи',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop(_VesselPhotoSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Сделать фото',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop(_VesselPhotoSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return null;
    }

    return switch (source) {
      _VesselPhotoSource.gallery =>
        _vesselPhotoPreparationService.prepareFromGallery(),

      _VesselPhotoSource.camera =>
        _vesselPhotoPreparationService.prepareWithCamera(),
    };
  }

  void _openVesselCard(_PreviewVessel vessel) {
    var isQuickEditMode = false;

    var selectedPhysicalType = vessel.physicalType;
    var selectedWorkType =
        vessel.registryEntry?.effectiveWorkType ?? vessel.workType;
    var quickEditInitialPhysicalType = selectedPhysicalType;
    var quickEditInitialWorkType = selectedWorkType;
    var isQuickEditSaving = false;
    PreparedVesselPhotoImages? preparedPhoto;
    var isPhotoPreparing = false;
    var currentPhotoFullPath = vessel.registryEntry?.effectivePhotoFullPath;

    var currentPhotoVersion = vessel.registryEntry?.photoVersion;

    final canManageVesselRegistry = _spacesAccessRole.canManageVesselRegistry;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBackgroundColor,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final physicalTypeText =
                selectedPhysicalType == VesselPhysicalType.unknown
                ? 'Не определён'
                : selectedPhysicalType.displayName;

            final workTypeText = selectedWorkType == VesselWorkType.unknown
                ? 'Не определён'
                : selectedWorkType.displayName;

            final latestRegistryEntry = _vesselRegistry
                .resolve(shipName: vessel.name, lineName: vessel.lineName)
                .vessel;

            final currentRegistryEntry =
                latestRegistryEntry ?? vessel.registryEntry;

            final currentImo =
                currentRegistryEntry?.imo?.trim() ?? vessel.imo.trim();

            final workTypeColor = selectedWorkType == VesselWorkType.unknown
                ? null
                : _vesselWorkTypeColor(selectedWorkType);

            final classColor = workTypeColor ?? _unknownColor;

            final vesselCardBackgroundColor = HSVColor.fromColor(
              classColor,
            ).withSaturation(0.72).withValue(0.26).toColor();

            final isContainerLike =
                selectedPhysicalType == VesselPhysicalType.container ||
                selectedPhysicalType == VesselPhysicalType.reefer;

            return SafeArea(
              child: ColoredBox(
                color: vesselCardBackgroundColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        children: [
                          Center(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap:
                                  !isQuickEditMode ||
                                      isQuickEditSaving ||
                                      isPhotoPreparing
                                  ? null
                                  : () async {
                                      setSheetState(() {
                                        isPhotoPreparing = true;
                                      });

                                      try {
                                        final selectedPhoto =
                                            await _chooseVesselPhoto(
                                              sheetContext,
                                            );

                                        if (selectedPhoto == null) {
                                          return;
                                        }

                                        if (!sheetContext.mounted) {
                                          await selectedPhoto.cleanup();
                                          return;
                                        }

                                        final previousPhoto = preparedPhoto;

                                        setSheetState(() {
                                          preparedPhoto = selectedPhoto;
                                        });

                                        if (previousPhoto != null) {
                                          await previousPhoto.cleanup();
                                        }
                                      } catch (_) {
                                        if (sheetContext.mounted) {
                                          ScaffoldMessenger.of(sheetContext)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Не удалось подготовить фотографию.',
                                                ),
                                              ),
                                            );
                                        }
                                      } finally {
                                        if (sheetContext.mounted) {
                                          setSheetState(() {
                                            isPhotoPreparing = false;
                                          });
                                        }
                                      }
                                    },
                              child: SizedBox(
                                width: double.infinity,
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (preparedPhoto != null)
                                        Image.file(
                                          preparedPhoto!.fullFile,
                                          fit: BoxFit.cover,
                                        )
                                      else
                                        VesselPhotoImage(
                                          storagePath: currentPhotoFullPath,
                                          version: currentPhotoVersion,
                                          width: double.infinity,
                                          height: double.infinity,
                                          borderRadius: BorderRadius.zero,
                                          urlResolver:
                                              _vesselPhotoUrlCache.resolve,
                                          fallbackBuilder: (context) {
                                            return Container(
                                              color: _dayBackgroundColor,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.directions_boat_rounded,
                                                color: Colors.white,
                                                size: 72,
                                              ),
                                            );
                                          },
                                        ),

                                      // Нижняя часть фотографии затемняется,
                                      // чтобы название и тип судна всегда читались.
                                      IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              stops: const [0.42, 0.70, 1.0],
                                              colors: [
                                                Colors.transparent,
                                                Color(0x33000000),
                                                Color(0xD9000000),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Лёгкое размытие нижней части фотографии.
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        height: 82,
                                        child: IgnorePointer(
                                          child: ClipRect(
                                            child: BackdropFilter(
                                              filter: ui.ImageFilter.blur(
                                                sigmaX: 1,
                                                sigmaY: 1,
                                              ),
                                              child: const SizedBox.expand(),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Фото плавно растворяется в фоне карточки.
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        height: 110,
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                stops: const [
                                                  0.0,
                                                  0.42,
                                                  0.72,
                                                  1.0,
                                                ],
                                                colors: [
                                                  Colors.transparent,
                                                  vesselCardBackgroundColor
                                                      .withValues(alpha: 0.18),
                                                  vesselCardBackgroundColor
                                                      .withValues(alpha: 0.62),
                                                  vesselCardBackgroundColor,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: Container(
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.42,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 20,
                                        right: 20,
                                        bottom: 18,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              vessel.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 25,
                                                fontWeight: FontWeight.w800,
                                                height: 1.05,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              '$physicalTypeText · $workTypeText',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFFD7E4EF),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      if (isQuickEditMode)
                                        Positioned(
                                          top: 16,
                                          left: 20,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.58,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              isPhotoPreparing
                                                  ? 'Подготовка...'
                                                  : 'Изменить фото',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (canManageVesselRegistry)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: _VesselEditButton(
                                isQuickEditMode: isQuickEditMode,
                                onTap: () {
                                  if (isQuickEditMode) {
                                    return;
                                  }

                                  setSheetState(() {
                                    quickEditInitialPhysicalType =
                                        selectedPhysicalType;
                                    quickEditInitialWorkType = selectedWorkType;
                                    isQuickEditMode = true;
                                  });
                                },
                                onSpecialEdit: () {
                                  unawaited(
                                    _openSpecialVesselEditor(
                                      vessel: vessel,
                                      initialPhysicalType: selectedPhysicalType,
                                      initialWorkType: selectedWorkType,
                                    ).then((result) async {
                                      if (result == null ||
                                          !sheetContext.mounted) {
                                        return;
                                      }

                                      final saved =
                                          await _saveVesselRegistryEntry(
                                            vessel: vessel,
                                            physicalType: result.physicalType,
                                            workType: result.workType,
                                            imo: result.imo,
                                            lengthMeters: result.lengthMeters,
                                            deadweightTons:
                                                result.deadweightTons,
                                            teuCapacity: result.teuCapacity,
                                            marineTrafficUrl:
                                                result.marineTrafficUrl,
                                            markVerified: true,
                                          );

                                      if (!saved || !sheetContext.mounted) {
                                        return;
                                      }

                                      setSheetState(() {
                                        selectedPhysicalType =
                                            result.physicalType;
                                        selectedWorkType = result.workType;
                                      });
                                    }),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (vessel.lineName.trim().isNotEmpty)
                              _VesselFact(
                                label: 'Линия',
                                value: vessel.lineName,
                              ),
                            if (currentImo.isNotEmpty)
                              _VesselFact(label: 'IMO', value: currentImo),
                            const SizedBox(height: 4),
                            if (isQuickEditMode)
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Тип судна',
                                          style: TextStyle(
                                            color: _secondaryTextColor,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: _VesselChoiceButton(
                                          label:
                                              selectedPhysicalType ==
                                                  VesselPhysicalType.unknown
                                              ? 'Выбрать'
                                              : physicalTypeText,
                                          onTap: () async {
                                            final selected =
                                                await _showVesselPhysicalTypePicker(
                                                  context: sheetContext,
                                                  selectedType:
                                                      selectedPhysicalType,
                                                );

                                            if (selected == null ||
                                                !sheetContext.mounted) {
                                              return;
                                            }

                                            setSheetState(() {
                                              selectedPhysicalType = selected;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Тип груза / захода',
                                          style: TextStyle(
                                            color: _secondaryTextColor,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: _VesselChoiceButton(
                                          label:
                                              selectedWorkType ==
                                                  VesselWorkType.unknown
                                              ? 'Выбрать'
                                              : workTypeText,
                                          color: workTypeColor,
                                          onTap: () async {
                                            final selected =
                                                await _showVesselWorkTypePicker(
                                                  context: sheetContext,
                                                  selectedType:
                                                      selectedWorkType,
                                                );

                                            if (selected == null ||
                                                !sheetContext.mounted) {
                                              return;
                                            }

                                            setSheetState(() {
                                              selectedWorkType = selected;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: isQuickEditSaving
                                              ? null
                                              : () {
                                                  setSheetState(() {
                                                    selectedPhysicalType =
                                                        quickEditInitialPhysicalType;
                                                    selectedWorkType =
                                                        quickEditInitialWorkType;
                                                    isQuickEditMode = false;
                                                  });
                                                },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.45,
                                              ),
                                              width: 1.2,
                                            ),
                                          ),
                                          icon: const Icon(Icons.close_rounded),
                                          label: const Text(
                                            'Отмена',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: isQuickEditSaving
                                              ? null
                                              : () {
                                                  setSheetState(() {
                                                    isQuickEditSaving = true;
                                                  });

                                                  unawaited(() async {
                                                    final photoToSave =
                                                        preparedPhoto;

                                                    final saved =
                                                        await _saveVesselRegistryEntry(
                                                          vessel: vessel,
                                                          physicalType:
                                                              selectedPhysicalType,
                                                          workType:
                                                              selectedWorkType,
                                                          imo:
                                                              vessel
                                                                  .registryEntry
                                                                  ?.imo ??
                                                              vessel.imo,
                                                          lengthMeters: vessel
                                                              .registryEntry
                                                              ?.lengthMeters,
                                                          deadweightTons: vessel
                                                              .registryEntry
                                                              ?.deadweightTons,
                                                          teuCapacity: vessel
                                                              .registryEntry
                                                              ?.teuCapacity,
                                                          marineTrafficUrl: vessel
                                                              .registryEntry
                                                              ?.marineTrafficUrl,
                                                          markVerified: false,
                                                        );

                                                    if (!saved) {
                                                      if (sheetContext
                                                          .mounted) {
                                                        setSheetState(() {
                                                          isQuickEditSaving =
                                                              false;
                                                        });
                                                      }

                                                      return;
                                                    }

                                                    if (photoToSave != null) {
                                                      try {
                                                        final refreshedEntry =
                                                            _vesselRegistry
                                                                .resolve(
                                                                  shipName:
                                                                      vessel
                                                                          .name,
                                                                  lineName: vessel
                                                                      .lineName,
                                                                )
                                                                .vessel;

                                                        if (refreshedEntry ==
                                                            null) {
                                                          throw StateError(
                                                            'Saved vessel registry entry was not found.',
                                                          );
                                                        }

                                                        final result =
                                                            await _vesselPhotoReplacementService.replace(
                                                              vessel:
                                                                  refreshedEntry,
                                                              images:
                                                                  photoToSave,
                                                              updatedBy:
                                                                  _currentUserId,
                                                            );

                                                        currentPhotoFullPath =
                                                            result.fullPath;

                                                        currentPhotoVersion =
                                                            result.version;

                                                        // Новый Storage path получает новый cache key.
                                                        // Подготовим thumb выбранного дня сразу.
                                                        await _vesselPhotoUrlCache
                                                            .resolve(
                                                              result
                                                                  .thumbnailPath,
                                                            );

                                                        _vesselRegistry =
                                                            await _vesselRegistryService
                                                                .load();

                                                        await _reloadPreviewCallsFromLocalMonth();
                                                      } catch (_) {
                                                        if (!sheetContext
                                                            .mounted) {
                                                          return;
                                                        }

                                                        setSheetState(() {
                                                          isQuickEditSaving =
                                                              false;
                                                        });

                                                        ScaffoldMessenger.of(
                                                            sheetContext,
                                                          )
                                                          ..hideCurrentSnackBar()
                                                          ..showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Данные судна сохранены, '
                                                                'но фотографию загрузить не удалось.',
                                                              ),
                                                            ),
                                                          );

                                                        return;
                                                      }
                                                    }

                                                    if (!sheetContext.mounted) {
                                                      return;
                                                    }

                                                    setSheetState(() {
                                                      isQuickEditSaving = false;

                                                      quickEditInitialPhysicalType =
                                                          selectedPhysicalType;

                                                      quickEditInitialWorkType =
                                                          selectedWorkType;

                                                      preparedPhoto = null;
                                                      isQuickEditMode = false;
                                                    });
                                                  }());
                                                },
                                          icon: isQuickEditSaving
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.check_rounded),
                                          label: Text(
                                            isQuickEditSaving
                                                ? 'Сохранение...'
                                                : 'Сохранить',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  _VesselFact(
                                    label: 'Тип судна',
                                    value: physicalTypeText,
                                  ),
                                  const SizedBox(height: 12),
                                  _VesselFact(
                                    label: 'Тип груза / захода',
                                    value: workTypeText,
                                  ),
                                ],
                              ),

                            const SizedBox(height: 12),
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
                            if (isContainerLike)
                              if (vessel.capacityLabel != null)
                                _VesselFact(
                                  label: 'Вместимость',
                                  value: vessel.capacityLabel!,
                                )
                              else if (vessel.deadweightTons != null)
                                _VesselFact(
                                  label: 'DWT',
                                  value: '${vessel.deadweightTons} т',
                                )
                              else if (vessel.deadweightTons != null)
                                _VesselFact(
                                  label: 'DWT',
                                  value: '${vessel.deadweightTons} т',
                                )
                              else if (vessel.capacityLabel != null)
                                _VesselFact(
                                  label: 'Вместимость',
                                  value: vessel.capacityLabel!,
                                ),
                          ],
                        ),
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
                      photoUrlResolver: _vesselPhotoUrlCache.resolve,
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

enum _VesselPhotoSource { gallery, camera }

class _VesselCallCard extends StatelessWidget {
  const _VesselCallCard({
    required this.call,
    required this.color,
    required this.now,
    required this.photoUrlResolver,
    required this.onPhotoTap,
    required this.onMarineTrafficTap,
  });

  final _PreviewVesselCall call;

  final Color color;
  final DateTime now;
  final VesselPhotoUrlResolver photoUrlResolver;

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

    final cardBackgroundColor = HSVColor.fromColor(
      color,
    ).withSaturation(0.62).withValue(0.22).toColor();

    return Container(
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 112,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onPhotoTap,
                  child: Container(
                    width: 112,
                    height: 63,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: VesselPhotoImage(
                      storagePath:
                          call.vessel.registryEntry?.effectivePhotoThumbPath,
                      version: call.vessel.registryEntry?.photoVersion,
                      width: 112,
                      height: 63,
                      borderRadius: BorderRadius.circular(12),
                      urlResolver: photoUrlResolver,
                      fallbackBuilder: (context) {
                        return Icon(
                          Icons.directions_boat_rounded,
                          size: 36,
                          color: color,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 112,
                  child: FilledButton.tonalIcon(
                    onPressed: onMarineTrafficTap,
                    icon: const Icon(
                      Icons.location_searching_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'Где судно',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 7,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  call.vessel.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Center(
                  child: Text(
                    call.vessel.workTypeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _VesselCallsSpaceScreenState._secondaryTextColor,
                      fontSize: 13,
                    ),
                  ),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDateTime(call.berthFrom),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(call.berthTo),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime date) {
    final portDate = date.toUtc().add(const Duration(hours: 3));

    final day = portDate.day.toString().padLeft(2, '0');
    final month = portDate.month.toString().padLeft(2, '0');
    final hour = portDate.hour.toString().padLeft(2, '0');
    final minute = portDate.minute.toString().padLeft(2, '0');

    return '$day.$month / $hour:$minute';
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

class _VesselEditButton extends StatefulWidget {
  const _VesselEditButton({
    required this.isQuickEditMode,
    required this.onTap,
    required this.onSpecialEdit,
  });

  final bool isQuickEditMode;
  final VoidCallback onTap;
  final VoidCallback onSpecialEdit;

  @override
  State<_VesselEditButton> createState() => _VesselEditButtonState();
}

class _VesselEditButtonState extends State<_VesselEditButton>
    with SingleTickerProviderStateMixin {
  static const Duration _progressDelay = Duration(milliseconds: 500);
  static const Duration _totalHoldDuration = Duration(seconds: 3);

  late final AnimationController _progressController;

  Timer? _delayTimer;
  Timer? _completeTimer;

  bool _isHolding = false;
  bool _showProgress = false;
  bool _specialEditTriggered = false;

  @override
  void initState() {
    super.initState();

    final progressDuration = _totalHoldDuration - _progressDelay;

    _progressController = AnimationController(
      vsync: this,
      duration: progressDuration,
    );
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _completeTimer?.cancel();
    _progressController.dispose();

    super.dispose();
  }

  void _startHold() {
    _cancelTimers();

    _isHolding = true;
    _showProgress = false;
    _specialEditTriggered = false;

    _progressController
      ..stop()
      ..value = 0;

    _delayTimer = Timer(_progressDelay, () {
      if (!mounted || !_isHolding) {
        return;
      }

      setState(() {
        _showProgress = true;
      });

      _progressController.forward();
    });

    _completeTimer = Timer(_totalHoldDuration, () {
      if (!mounted || !_isHolding) {
        return;
      }

      _specialEditTriggered = true;
      _isHolding = false;

      _delayTimer?.cancel();

      setState(() {
        _showProgress = false;
      });

      _progressController
        ..stop()
        ..value = 0;

      widget.onSpecialEdit();
    });
  }

  void _finishHold() {
    if (!_isHolding) {
      return;
    }

    final shouldHandleTap = !_specialEditTriggered;

    _isHolding = false;

    _cancelTimers();

    if (_showProgress) {
      setState(() {
        _showProgress = false;
      });
    }

    _progressController
      ..stop()
      ..value = 0;

    if (shouldHandleTap) {
      widget.onTap();
    }
  }

  void _cancelHold() {
    if (!_isHolding) {
      return;
    }

    _isHolding = false;

    _cancelTimers();

    if (_showProgress) {
      setState(() {
        _showProgress = false;
      });
    }

    _progressController
      ..stop()
      ..value = 0;
  }

  void _cancelTimers() {
    _delayTimer?.cancel();
    _delayTimer = null;

    _completeTimer?.cancel();
    _completeTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _startHold();
      },
      onTapUp: (_) {
        _finishHold();
      },
      onTapCancel: _cancelHold,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_showProgress)
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      value: _progressController.value,
                      strokeWidth: 2.5,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      color: Colors.white,
                    ),
                  );
                },
              ),
            Icon(
              widget.isQuickEditMode ? Icons.check_rounded : Icons.edit_rounded,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _VesselSpecialEditResult {
  const _VesselSpecialEditResult({
    required this.physicalType,
    required this.workType,
    required this.imo,
    required this.lengthMeters,
    required this.deadweightTons,
    required this.teuCapacity,
    required this.marineTrafficUrl,
  });

  final VesselPhysicalType physicalType;
  final VesselWorkType workType;

  final String? imo;
  final double? lengthMeters;
  final int? deadweightTons;
  final int? teuCapacity;
  final String? marineTrafficUrl;
}

class _VesselChoiceButton extends StatelessWidget {
  const _VesselChoiceButton({
    required this.label,
    required this.onTap,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final borderColor = color ?? Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (color != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
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

enum _VesselType { container, bulk, service, other, unknown }

enum _VesselOperationKind { cargo, layby }

class _PreviewVessel {
  const _PreviewVessel({
    required this.name,
    required this.lineName,
    required this.imo,
    required this.mmsi,
    required this.physicalType,
    required this.workType,
    required this.physicalTypeLabel,
    required this.workTypeLabel,
    required this.lengthMeters,
    required this.widthMeters,
    required this.deadweightTons,
    required this.capacityLabel,
    required this.registryEntry,
  });

  final String name;
  final String lineName;
  final String imo;
  final String mmsi;

  final VesselPhysicalType physicalType;
  final VesselWorkType workType;

  final String physicalTypeLabel;
  final String workTypeLabel;

  final int? lengthMeters;
  final int? widthMeters;
  final int? deadweightTons;
  final String? capacityLabel;

  final VesselRegistryEntry? registryEntry;

  bool get hasRegistryEntry {
    return registryEntry != null;
  }

  bool get supportsWorkTypeSwitch {
    return registryEntry?.supportsWorkTypeSwitch ?? false;
  }
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

Color _vesselWorkTypeColor(VesselWorkType workType) {
  return switch (workType) {
    VesselWorkType.container => _VesselCallsSpaceScreenState._containerColor,
    VesselWorkType.bulk => _VesselCallsSpaceScreenState._bulkColor,
    VesselWorkType.special => _VesselCallsSpaceScreenState._laybyColor,
    VesselWorkType.other => _VesselCallsSpaceScreenState._otherCargoColor,
    VesselWorkType.unknown => _VesselCallsSpaceScreenState._unknownColor,
  };
}

Color _vesselCallColor(
  _PreviewVesselCall call, {
  required Color containerColor,
  required Color bulkColor,
  required Color laybyColor,
  DateTime? now,
}) {
  if (call.operationKind == _VesselOperationKind.layby) {
    return laybyColor;
  }

  final baseColor = switch (call.vesselType) {
    _VesselType.container => containerColor,
    _VesselType.bulk => bulkColor,
    _VesselType.service => laybyColor,
    _VesselType.other => _VesselCallsSpaceScreenState._otherCargoColor,
    _VesselType.unknown => _VesselCallsSpaceScreenState._unknownColor,
  };

  final resolvedNow = now ?? DateTime.now();

  if (!call.berthTo.isAfter(resolvedNow)) {
    return baseColor.withValues(alpha: 0.42);
  }

  return baseColor;
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
