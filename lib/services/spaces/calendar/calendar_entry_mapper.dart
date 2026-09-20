import '../../../domain/models/calendar_entry.dart';

final class CalendarEntryMapper {
  const CalendarEntryMapper._();

  static const int schemaVersion = 1;

  static Map<String, Object?> toMap(CalendarEntry entry) {
    if (!entry.isValid) {
      throw ArgumentError.value(
        entry,
        'entry',
        'must be a valid calendar entry',
      );
    }

    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'id': entry.id.trim(),
      'kind': entry.kind.name,
      'day': entry.dayKey,
      'title': entry.title.trim(),
      'description': _normalizedText(entry.description),
      'scheduledMinutes': entry.scheduledMinutes,
      'reminderMinutes': entry.reminderMinutes,
      'priority': entry.priority.name,
      'colorValue': entry.colorValue,
      'isCompleted': entry.isCompleted,
      'completedAt': entry.completedAt?.toUtc().millisecondsSinceEpoch,
      'createdAt': entry.createdAt.toUtc().millisecondsSinceEpoch,
      'updatedAt': entry.updatedAt.toUtc().millisecondsSinceEpoch,
    };
  }

  static CalendarEntry fromMap(Map<String, Object?> map) {
    final version = map['schemaVersion'];
    if (version != schemaVersion) {
      throw const FormatException('Unsupported calendar entry schema version.');
    }

    final id = map['id'];
    final kindValue = map['kind'];
    final dayValue = map['day'];
    final title = map['title'];
    final priorityValue = map['priority'];
    final isCompleted = map['isCompleted'];
    final createdAtValue = map['createdAt'];
    final updatedAtValue = map['updatedAt'];

    if (id is! String ||
        kindValue is! String ||
        dayValue is! int ||
        title is! String ||
        priorityValue is! String ||
        isCompleted is! bool ||
        createdAtValue is! int ||
        updatedAtValue is! int) {
      throw const FormatException('Invalid calendar entry data.');
    }

    final entry = CalendarEntry(
      id: id,
      kind: _parseKind(kindValue),
      date: _dateFromDayKey(dayValue),
      title: title,
      description: _nullableString(map['description']),
      scheduledMinutes: _nullableInt(map['scheduledMinutes']),
      reminderMinutes: _nullableInt(map['reminderMinutes']),
      priority: _parsePriority(priorityValue),
      colorValue: _nullableInt(map['colorValue']),
      isCompleted: isCompleted,
      completedAt: _nullableDateTime(map['completedAt']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtValue,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        updatedAtValue,
        isUtc: true,
      ),
    );

    if (!entry.isValid) {
      throw const FormatException('Calendar entry is invalid.');
    }

    return entry;
  }

  static CalendarEntryKind _parseKind(String value) {
    for (final kind in CalendarEntryKind.values) {
      if (kind.name == value) {
        return kind;
      }
    }

    throw FormatException('Unknown calendar entry kind: $value');
  }

  static CalendarEntryPriority _parsePriority(String value) {
    for (final priority in CalendarEntryPriority.values) {
      if (priority.name == value) {
        return priority;
      }
    }

    throw FormatException('Unknown calendar entry priority: $value');
  }

  static DateTime _dateFromDayKey(int value) {
    final year = value ~/ 10000;
    final month = value ~/ 100 % 100;
    final day = value % 100;

    final date = DateTime(year, month, day);

    if (date.year != year || date.month != month || date.day != day) {
      throw const FormatException('Invalid calendar entry day.');
    }

    return date;
  }

  static String? _normalizedText(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  static String? _nullableString(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value;
    }

    throw const FormatException('Expected nullable String.');
  }

  static int? _nullableInt(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    throw const FormatException('Expected nullable int.');
  }

  static DateTime? _nullableDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is! int) {
      throw const FormatException('Expected nullable timestamp.');
    }

    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
}
