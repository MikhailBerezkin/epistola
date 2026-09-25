import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/shift_alarm.dart';
import 'shift_alarm_mapper.dart';

final class ShiftAlarmLocalStore {
  const ShiftAlarmLocalStore();

  static const int _storageSchemaVersion = 1;
  static const String _storageKeyPrefix = 'shift_alarms_v1';

  Future<List<ShiftAlarm>> loadForUser({required String userId}) async {
    final normalizedUserId = _normalizeUserId(userId);
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_storageKey(normalizedUserId));

    if (rawValue == null || rawValue.isEmpty) {
      return const <ShiftAlarm>[];
    }

    final decoded = jsonDecode(rawValue);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid shift alarm storage.');
    }

    final schemaVersion = decoded['schemaVersion'];
    final rawAlarms = decoded['alarms'];

    if (schemaVersion != _storageSchemaVersion || rawAlarms is! List<dynamic>) {
      throw const FormatException('Unsupported shift alarm storage.');
    }

    final alarms = <ShiftAlarm>[];

    for (final rawAlarm in rawAlarms) {
      if (rawAlarm is! Map<String, dynamic>) {
        throw const FormatException('Invalid shift alarm storage item.');
      }

      alarms.add(ShiftAlarmMapper.fromMap(Map<String, Object?>.from(rawAlarm)));
    }

    return alarms;
  }

  Future<void> save({required String userId, required ShiftAlarm alarm}) async {
    final normalizedUserId = _normalizeUserId(userId);

    if (!alarm.isValid) {
      throw ArgumentError.value(alarm, 'alarm', 'must be a valid shift alarm');
    }

    final alarms = await loadForUser(userId: normalizedUserId);
    final updatedAlarms = <ShiftAlarm>[...alarms];

    final existingIndex = updatedAlarms.indexWhere(
      (candidate) => candidate.id == alarm.id,
    );

    if (existingIndex >= 0) {
      updatedAlarms[existingIndex] = alarm;
    } else {
      updatedAlarms.add(alarm);
    }

    await _write(userId: normalizedUserId, alarms: updatedAlarms);
  }

  Future<void> delete({required String userId, required String alarmId}) async {
    final normalizedUserId = _normalizeUserId(userId);
    final normalizedAlarmId = alarmId.trim();

    if (normalizedAlarmId.isEmpty) {
      throw ArgumentError.value(alarmId, 'alarmId', 'must not be empty');
    }

    final alarms = await loadForUser(userId: normalizedUserId);

    final updatedAlarms = alarms
        .where((alarm) => alarm.id != normalizedAlarmId)
        .toList(growable: false);

    await _write(userId: normalizedUserId, alarms: updatedAlarms);
  }

  Future<void> _write({
    required String userId,
    required List<ShiftAlarm> alarms,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final payload = <String, Object?>{
      'schemaVersion': _storageSchemaVersion,
      'alarms': alarms.map(ShiftAlarmMapper.toMap).toList(growable: false),
    };

    final success = await prefs.setString(
      _storageKey(userId),
      jsonEncode(payload),
    );

    if (!success) {
      throw StateError('Failed to save shift alarms.');
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
