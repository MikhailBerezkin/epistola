import '../../../domain/models/shift_alarm.dart';
import '../../../domain/models/shift_cycle.dart';

final class ShiftAlarmMapper {
  const ShiftAlarmMapper._();

  static const int schemaVersion = 1;

  static Map<String, Object?> toMap(ShiftAlarm alarm) {
    if (!alarm.isValid) {
      throw ArgumentError.value(alarm, 'alarm', 'must be a valid shift alarm');
    }

    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'id': alarm.id.trim(),
      'phase': alarm.phase.name,
      'scope': alarm.scope.name,
      'type': alarm.type.name,
      'title': alarm.title.trim(),
      'minutesOfDay': alarm.minutesOfDay,
      'durationSeconds': alarm.durationSeconds,
      'enabled': alarm.enabled,
      'createdAt': alarm.createdAt.toUtc().millisecondsSinceEpoch,
      'updatedAt': alarm.updatedAt.toUtc().millisecondsSinceEpoch,
    };
  }

  static ShiftAlarm fromMap(Map<String, Object?> map) {
    final version = map['schemaVersion'];

    if (version != schemaVersion) {
      throw const FormatException('Unsupported shift alarm schema version.');
    }

    final id = map['id'];
    final phaseValue = map['phase'];
    final scopeValue = map['scope'];
    final typeValue = map['type'];
    final title = map['title'];
    final minutesOfDay = map['minutesOfDay'];
    final enabled = map['enabled'];
    final createdAtValue = map['createdAt'];
    final updatedAtValue = map['updatedAt'];

    if (id is! String ||
        phaseValue is! String ||
        scopeValue is! String ||
        typeValue is! String ||
        title is! String ||
        minutesOfDay is! int ||
        enabled is! bool ||
        createdAtValue is! int ||
        updatedAtValue is! int) {
      throw const FormatException('Invalid shift alarm data.');
    }

    final alarm = ShiftAlarm(
      id: id,
      phase: _parsePhase(phaseValue),
      scope: _parseScope(scopeValue),
      type: _parseType(typeValue),
      title: title,
      minutesOfDay: minutesOfDay,
      durationSeconds: _nullableInt(map['durationSeconds']),
      enabled: enabled,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtValue,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        updatedAtValue,
        isUtc: true,
      ),
    );

    if (!alarm.isValid) {
      throw const FormatException('Shift alarm is invalid.');
    }

    return alarm;
  }

  static ShiftCyclePhase _parsePhase(String value) {
    for (final phase in ShiftCyclePhase.values) {
      if (phase.name == value) {
        return phase;
      }
    }

    throw FormatException('Unknown shift alarm phase: $value');
  }

  static ShiftAlarmScope _parseScope(String value) {
    for (final scope in ShiftAlarmScope.values) {
      if (scope.name == value) {
        return scope;
      }
    }

    throw FormatException('Unknown shift alarm scope: $value');
  }

  static ShiftAlarmType _parseType(String value) {
    for (final type in ShiftAlarmType.values) {
      if (type.name == value) {
        return type;
      }
    }

    throw FormatException('Unknown shift alarm type: $value');
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
}
