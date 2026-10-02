import 'vessel_calls_current_month_firestore_gateway.dart';
import 'vessel_calls_local_cache.dart';
import 'vessel_calls_month_archive_firestore_gateway.dart';

enum VesselCallsMonthFreshness { missing, fresh, refreshDue, archived }

enum VesselCallsCurrentMonthRefreshResult {
  notDue,
  unchanged,
  rebuilt,
  localMonthMissing,
  remoteMetaMissing,
  remoteSnapshotMissing,
}

final class VesselCallsMonthCacheService {
  VesselCallsMonthCacheService({
    required this._localCache,
    required this._archiveGateway,
    required this._currentMonthGateway,
  });

  factory VesselCallsMonthCacheService.firebase({
    VesselCallsLocalCache? localCache,
    VesselCallsMonthArchiveFirestoreGateway? archiveGateway,
    VesselCallsCurrentMonthFirestoreGateway? currentMonthGateway,
  }) {
    return VesselCallsMonthCacheService(
      localCache: localCache ?? VesselCallsLocalCache(),
      archiveGateway:
          archiveGateway ?? VesselCallsMonthArchiveFirestoreGateway.firebase(),
      currentMonthGateway:
          currentMonthGateway ??
          VesselCallsCurrentMonthFirestoreGateway.firebase(),
    );
  }

  final VesselCallsLocalCache _localCache;

  final VesselCallsMonthArchiveFirestoreGateway _archiveGateway;

  final VesselCallsCurrentMonthFirestoreGateway _currentMonthGateway;

  Future<CachedVesselMonth?> readLocalMonth({
    required int year,
    required int month,
  }) {
    return _localCache.readMonth(year: year, month: month);
  }

  Future<VesselCallsMonthFreshness> freshnessForCurrentMonth({
    required int year,
    required int month,
    DateTime? now,
  }) async {
    final localMonth = await _localCache.readMonth(year: year, month: month);

    if (localMonth == null) {
      return VesselCallsMonthFreshness.missing;
    }

    if (localMonth.isArchived) {
      return VesselCallsMonthFreshness.archived;
    }

    final shouldRefresh = await _localCache.shouldRefreshFullCalendar(
      year: year,
      month: month,
      now: now,
    );

    return shouldRefresh
        ? VesselCallsMonthFreshness.refreshDue
        : VesselCallsMonthFreshness.fresh;
  }

  Future<VesselCallsCurrentMonthRefreshResult> refreshCurrentMonthIfDue({
    required int year,
    required int month,
    DateTime? now,
  }) async {
    final localMonth = await _localCache.readMonth(year: year, month: month);

    if (localMonth == null) {
      return VesselCallsCurrentMonthRefreshResult.localMonthMissing;
    }

    final shouldRefresh = await _localCache.shouldRefreshFullCalendar(
      year: year,
      month: month,
      now: now,
    );

    if (!shouldRefresh) {
      return VesselCallsCurrentMonthRefreshResult.notDue;
    }

    final remoteRevision = await _currentMonthGateway.loadRevision(
      year: year,
      month: month,
    );

    if (remoteRevision == null) {
      return VesselCallsCurrentMonthRefreshResult.remoteMetaMissing;
    }

    if (remoteRevision.revision == localMonth.revision) {
      await _localCache.markFullCalendarSynced(
        year: year,
        month: month,
        at: now,
      );

      return VesselCallsCurrentMonthRefreshResult.unchanged;
    }

    final snapshotData = await _currentMonthGateway.loadSnapshot(
      year: year,
      month: month,
    );

    if (snapshotData == null) {
      return VesselCallsCurrentMonthRefreshResult.remoteSnapshotMissing;
    }

    final remoteSnapshot = CachedVesselMonth.fromJson(snapshotData);

    final rebuiltMonth = await _localCache.rebuildFromMonthlySnapshot(
      snapshot: remoteSnapshot,
      localMonth: localMonth,
    );

    await _localCache.writeMonth(rebuiltMonth);

    await _localCache.markFullCalendarSynced(year: year, month: month, at: now);

    return VesselCallsCurrentMonthRefreshResult.rebuilt;
  }

  Future<CachedVesselMonth?> loadArchivedMonth({
    required int year,
    required int month,
  }) async {
    final localMonth = await _localCache.readMonth(year: year, month: month);

    if (localMonth != null && localMonth.isArchived) {
      return localMonth;
    }

    final archiveData = await _archiveGateway.loadMonth(
      year: year,
      month: month,
    );

    if (archiveData == null) {
      return localMonth;
    }

    final archivedMonth = CachedVesselMonth.fromJson(archiveData);

    await _localCache.writeMonth(archivedMonth);

    return archivedMonth;
  }

  Future<void> markFullCalendarSynced({
    required int year,
    required int month,
    DateTime? at,
  }) {
    return _localCache.markFullCalendarSynced(year: year, month: month, at: at);
  }
}
