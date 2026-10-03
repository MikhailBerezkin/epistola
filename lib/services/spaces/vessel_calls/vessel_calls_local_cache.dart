import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VesselCallsLocalCache {
  VesselCallsLocalCache({this._preferences});

  SharedPreferences? _preferences;

  static const Duration revisionCheckInterval = Duration(minutes: 30);

  static const String _monthPrefix = 'vessel_calls_month_';

  static const String _lastRevisionCheckPrefix =
      'vessel_calls_last_revision_check_';

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<CachedVesselMonth?> readMonth({
    required int year,
    required int month,
  }) async {
    final prefs = await _prefs();

    final raw = prefs.getString(_monthKey(year, month));

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return CachedVesselMonth.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> writeMonth(CachedVesselMonth month) async {
    final prefs = await _prefs();

    await prefs.setString(
      _monthKey(month.year, month.month),
      jsonEncode(month.toJson()),
    );
  }

  Future<void> removeMonth({required int year, required int month}) async {
    final prefs = await _prefs();

    await prefs.remove(_monthKey(year, month));

    await prefs.remove(_lastRevisionCheckKey(year, month));
  }

  Future<DateTime?> readLastRevisionCheck({
    required int year,
    required int month,
  }) async {
    final prefs = await _prefs();

    final milliseconds = prefs.getInt(_lastRevisionCheckKey(year, month));

    if (milliseconds == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  Future<void> markRevisionChecked({
    required int year,
    required int month,
    DateTime? at,
  }) async {
    final prefs = await _prefs();

    final checkTime = at ?? DateTime.now();

    await prefs.setInt(
      _lastRevisionCheckKey(year, month),
      checkTime.millisecondsSinceEpoch,
    );
  }

  Future<bool> shouldCheckRevision({
    required int year,
    required int month,
    DateTime? now,
  }) async {
    final lastCheck = await readLastRevisionCheck(year: year, month: month);

    if (lastCheck == null) {
      return true;
    }

    final currentTime = now ?? DateTime.now();

    return currentTime.difference(lastCheck) >= revisionCheckInterval;
  }

  Future<CachedVesselMonth> applyOperationalChanges({
    required CachedVesselMonth month,
    required Iterable<CachedVesselCall> changes,
  }) async {
    final callsById = <String, CachedVesselCall>{
      for (final call in month.calls) call.id: call,
    };

    for (final change in changes) {
      final current = callsById[change.id];

      if (current == null || !change.updatedAt.isBefore(current.updatedAt)) {
        callsById[change.id] = change;
      }
    }

    final updatedCalls = callsById.values.toList()
      ..sort((left, right) => left.berthFrom.compareTo(right.berthFrom));

    final updatedMonth = month.copyWith(
      calls: updatedCalls,
      locallyUpdatedAt: DateTime.now(),
    );

    await writeMonth(updatedMonth);

    return updatedMonth;
  }

  Future<CachedVesselMonth> rebuildFromMonthlySnapshot({
    required CachedVesselMonth snapshot,
    required CachedVesselMonth? localMonth,
  }) async {
    if (localMonth == null) {
      await writeMonth(snapshot);

      return snapshot;
    }

    final snapshotCalls = <String, CachedVesselCall>{
      for (final call in snapshot.calls) call.id: call,
    };

    for (final localCall in localMonth.calls) {
      final snapshotCall = snapshotCalls[localCall.id];

      if (snapshotCall == null) {
        if (localCall.source == VesselCallCacheSource.operational) {
          snapshotCalls[localCall.id] = localCall;
        }

        continue;
      }

      if (localCall.source == VesselCallCacheSource.operational &&
          localCall.updatedAt.isAfter(snapshotCall.updatedAt)) {
        snapshotCalls[localCall.id] = localCall;
      }
    }

    final rebuiltCalls = snapshotCalls.values.toList()
      ..sort((left, right) => left.berthFrom.compareTo(right.berthFrom));

    final rebuilt = snapshot.copyWith(
      calls: rebuiltCalls,
      locallyUpdatedAt: DateTime.now(),
    );

    await writeMonth(rebuilt);

    return rebuilt;
  }

  static String _monthKey(int year, int month) {
    return '$_monthPrefix'
        '${year.toString().padLeft(4, '0')}_'
        '${month.toString().padLeft(2, '0')}';
  }

  static String _lastRevisionCheckKey(int year, int month) {
    return '$_lastRevisionCheckPrefix'
        '${year.toString().padLeft(4, '0')}_'
        '${month.toString().padLeft(2, '0')}';
  }
}

enum VesselCallCacheSource { monthlySnapshot, operational, archive }

class CachedVesselMonth {
  const CachedVesselMonth({
    required this.year,
    required this.month,
    required this.revision,
    required this.publishedUntil,
    required this.calls,
    required this.sourceUpdatedAt,
    required this.locallyUpdatedAt,
    required this.isArchived,
  });

  final int year;
  final int month;

  final int revision;

  /// Последняя дата, до которой издателем
  /// опубликован актуальный прогноз судозаходов.
  final DateTime? publishedUntil;

  final List<CachedVesselCall> calls;

  /// Время изменения исходного месячного
  /// документа на сервере.
  final DateTime sourceUpdatedAt;

  /// Последнее изменение локальной копии.
  final DateTime locallyUpdatedAt;

  final bool isArchived;

  CachedVesselMonth copyWith({
    int? revision,
    DateTime? publishedUntil,
    bool clearPublishedUntil = false,
    List<CachedVesselCall>? calls,
    DateTime? sourceUpdatedAt,
    DateTime? locallyUpdatedAt,
    bool? isArchived,
  }) {
    return CachedVesselMonth(
      year: year,
      month: month,
      revision: revision ?? this.revision,
      publishedUntil: clearPublishedUntil
          ? null
          : publishedUntil ?? this.publishedUntil,
      calls: calls ?? this.calls,
      sourceUpdatedAt: sourceUpdatedAt ?? this.sourceUpdatedAt,
      locallyUpdatedAt: locallyUpdatedAt ?? this.locallyUpdatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      'revision': revision,
      'publishedUntil': publishedUntil?.toIso8601String(),
      'calls': calls.map((call) => call.toJson()).toList(),
      'sourceUpdatedAt': sourceUpdatedAt.toIso8601String(),
      'locallyUpdatedAt': locallyUpdatedAt.toIso8601String(),
      'isArchived': isArchived,
    };
  }

  factory CachedVesselMonth.fromJson(Map<String, dynamic> json) {
    final rawCalls = json['calls'];

    return CachedVesselMonth(
      year: json['year'] as int,
      month: json['month'] as int,
      revision: json['revision'] as int? ?? 0,
      publishedUntil: _readOptionalDateTime(json['publishedUntil']),
      calls: rawCalls is List
          ? rawCalls
                .whereType<Map<String, dynamic>>()
                .map(CachedVesselCall.fromJson)
                .toList()
          : const [],
      sourceUpdatedAt: _readDateTime(json['sourceUpdatedAt']),
      locallyUpdatedAt: _readDateTime(json['locallyUpdatedAt']),
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }
}

class CachedVesselCall {
  const CachedVesselCall({
    required this.id,
    required this.vesselImo,
    required this.vesselName,
    required this.vesselType,
    required this.operationKind,
    required this.lane,
    required this.berthFrom,
    required this.berthTo,
    required this.updatedAt,
    required this.source,
  });

  final String id;

  /// Сейчас источник ещё не даёт настоящий IMO.
  /// До его подключения здесь временно хранится
  /// идентификатор захода.
  final String vesselImo;

  final String vesselName;

  final String vesselType;
  final String operationKind;

  /// Временная визуальная дорожка 0..3.
  /// Пока НЕ означает реальный причал.
  final int lane;

  final DateTime berthFrom;
  final DateTime berthTo;

  final DateTime updatedAt;

  final VesselCallCacheSource source;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vesselImo': vesselImo,
      'vesselName': vesselName,
      'vesselType': vesselType,
      'operationKind': operationKind,
      'lane': lane,
      'berthFrom': berthFrom.toIso8601String(),
      'berthTo': berthTo.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'source': source.name,
    };
  }

  factory CachedVesselCall.fromJson(Map<String, dynamic> json) {
    return CachedVesselCall(
      id: json['id'] as String,
      vesselImo: json['vesselImo'] as String,
      vesselName: json['vesselName'] as String,
      vesselType: json['vesselType'] as String,
      operationKind: json['operationKind'] as String,
      lane: json['lane'] as int,
      berthFrom: _readDateTime(json['berthFrom']),
      berthTo: _readDateTime(json['berthTo']),
      updatedAt: _readDateTime(json['updatedAt']),
      source: VesselCallCacheSource.values.firstWhere(
        (value) => value.name == json['source'],
        orElse: () => VesselCallCacheSource.monthlySnapshot,
      ),
    );
  }
}

DateTime _readDateTime(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);

    if (parsed != null) {
      return parsed;
    }
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _readOptionalDateTime(Object? value) {
  if (value is! String) {
    return null;
  }

  return DateTime.tryParse(value);
}
