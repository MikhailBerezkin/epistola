import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

final class ShiftAlarmScheduledItem {
  const ShiftAlarmScheduledItem({
    required this.occurrenceId,
    required this.notificationId,
  });

  final String occurrenceId;
  final int notificationId;

  bool get isValid {
    return occurrenceId.trim().isNotEmpty &&
        notificationId >= 0 &&
        notificationId <= 0x7fffffff;
  }
}

final class ShiftAlarmScheduleRegistry {
  const ShiftAlarmScheduleRegistry();

  static const int _storageSchemaVersion = 1;
  static const String _storageKeyPrefix = 'shift_alarm_schedule_registry_v1';

  Future<List<ShiftAlarmScheduledItem>> loadForUser({
    required String userId,
  }) async {
    final normalizedUserId = _normalizeUserId(userId);
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_storageKey(normalizedUserId));

    if (rawValue == null || rawValue.isEmpty) {
      return const <ShiftAlarmScheduledItem>[];
    }

    final decoded = jsonDecode(rawValue);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid shift alarm schedule registry.');
    }

    final schemaVersion = decoded['schemaVersion'];
    final rawItems = decoded['items'];

    if (schemaVersion != _storageSchemaVersion || rawItems is! List<dynamic>) {
      throw const FormatException('Unsupported shift alarm schedule registry.');
    }

    final items = <ShiftAlarmScheduledItem>[];

    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const FormatException(
          'Invalid shift alarm schedule registry item.',
        );
      }

      final occurrenceId = rawItem['occurrenceId'];
      final notificationId = rawItem['notificationId'];

      if (occurrenceId is! String || notificationId is! int) {
        throw const FormatException(
          'Invalid shift alarm schedule registry item.',
        );
      }

      final item = ShiftAlarmScheduledItem(
        occurrenceId: occurrenceId,
        notificationId: notificationId,
      );

      if (!item.isValid) {
        throw const FormatException('Invalid shift alarm scheduled item.');
      }

      items.add(item);
    }

    return items;
  }

  Future<void> replaceForUser({
    required String userId,
    required Iterable<ShiftAlarmScheduledItem> items,
  }) async {
    final normalizedUserId = _normalizeUserId(userId);
    final normalizedItems = items.toList(growable: false);

    for (final item in normalizedItems) {
      if (!item.isValid) {
        throw ArgumentError.value(
          item,
          'items',
          'must contain only valid scheduled items',
        );
      }
    }

    final occurrenceIds = <String>{};

    for (final item in normalizedItems) {
      if (!occurrenceIds.add(item.occurrenceId)) {
        throw ArgumentError.value(
          item.occurrenceId,
          'items',
          'must not contain duplicate occurrence ids',
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();

    final payload = <String, Object?>{
      'schemaVersion': _storageSchemaVersion,
      'items': normalizedItems
          .map(
            (item) => <String, Object?>{
              'occurrenceId': item.occurrenceId,
              'notificationId': item.notificationId,
            },
          )
          .toList(growable: false),
    };

    final success = await prefs.setString(
      _storageKey(normalizedUserId),
      jsonEncode(payload),
    );

    if (!success) {
      throw StateError('Failed to save shift alarm schedule registry.');
    }
  }

  Future<void> clearForUser({required String userId}) async {
    final normalizedUserId = _normalizeUserId(userId);
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey(normalizedUserId));
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
