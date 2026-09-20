import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/calendar_entry.dart';
import 'calendar_entry_mapper.dart';

final class CalendarEntryLocalStore {
  const CalendarEntryLocalStore();

  static const int _storageSchemaVersion = 1;
  static const String _storageKeyPrefix = 'calendar_entries_v1';

  Future<List<CalendarEntry>> loadForUser({required String userId}) async {
    final normalizedUserId = _normalizeUserId(userId);
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_storageKey(normalizedUserId));

    if (rawValue == null || rawValue.isEmpty) {
      return const <CalendarEntry>[];
    }

    final decoded = jsonDecode(rawValue);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid calendar entry storage.');
    }

    final schemaVersion = decoded['schemaVersion'];
    final rawEntries = decoded['entries'];

    if (schemaVersion != _storageSchemaVersion ||
        rawEntries is! List<dynamic>) {
      throw const FormatException('Unsupported calendar entry storage.');
    }

    final entries = <CalendarEntry>[];

    for (final rawEntry in rawEntries) {
      if (rawEntry is! Map<String, dynamic>) {
        throw const FormatException('Invalid calendar entry storage item.');
      }

      entries.add(
        CalendarEntryMapper.fromMap(Map<String, Object?>.from(rawEntry)),
      );
    }

    return entries;
  }

  Future<void> save({
    required String userId,
    required CalendarEntry entry,
  }) async {
    final normalizedUserId = _normalizeUserId(userId);

    if (!entry.isValid) {
      throw ArgumentError.value(
        entry,
        'entry',
        'must be a valid calendar entry',
      );
    }

    final entries = await loadForUser(userId: normalizedUserId);

    final updatedEntries = <CalendarEntry>[...entries];

    final existingIndex = updatedEntries.indexWhere(
      (candidate) => candidate.id == entry.id,
    );

    if (existingIndex >= 0) {
      updatedEntries[existingIndex] = entry;
    } else {
      updatedEntries.add(entry);
    }

    await _write(userId: normalizedUserId, entries: updatedEntries);
  }

  Future<void> delete({required String userId, required String entryId}) async {
    final normalizedUserId = _normalizeUserId(userId);
    final normalizedEntryId = entryId.trim();

    if (normalizedEntryId.isEmpty) {
      throw ArgumentError.value(entryId, 'entryId', 'must not be empty');
    }

    final entries = await loadForUser(userId: normalizedUserId);

    final updatedEntries = entries
        .where((entry) => entry.id != normalizedEntryId)
        .toList(growable: false);

    await _write(userId: normalizedUserId, entries: updatedEntries);
  }

  Future<void> _write({
    required String userId,
    required List<CalendarEntry> entries,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final payload = <String, Object?>{
      'schemaVersion': _storageSchemaVersion,
      'entries': entries.map(CalendarEntryMapper.toMap).toList(growable: false),
    };

    final success = await prefs.setString(
      _storageKey(userId),
      jsonEncode(payload),
    );

    if (!success) {
      throw StateError('Failed to save calendar entries.');
    }
  }

  static String _normalizeUserId(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'userId', 'must not be empty');
    }

    return normalized;
  }

  static String _storageKey(String userId) {
    return '${_storageKeyPrefix}_$userId';
  }
}
