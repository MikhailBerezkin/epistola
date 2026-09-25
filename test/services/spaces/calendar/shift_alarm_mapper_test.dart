import 'package:epistola/domain/models/shift_alarm.dart';
import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShiftAlarmMapper', () {
    test('round trips regular alarm', () {
      final timestamp = DateTime.utc(2026, 9, 25, 12);

      final source = ShiftAlarm(
        id: 'alarm-1',
        phase: ShiftCyclePhase.day1,
        scope: ShiftAlarmScope.work,
        type: ShiftAlarmType.alarm,
        title: ' Подъём ',
        minutesOfDay: 5 * 60 + 40,
        enabled: true,
        createdAt: timestamp,
        updatedAt: timestamp,
      );

      final map = ShiftAlarmMapper.toMap(source);
      final restored = ShiftAlarmMapper.fromMap(map);

      expect(restored.id, 'alarm-1');
      expect(restored.phase, ShiftCyclePhase.day1);
      expect(restored.scope, ShiftAlarmScope.work);
      expect(restored.type, ShiftAlarmType.alarm);
      expect(restored.title, 'Подъём');
      expect(restored.minutesOfDay, 5 * 60 + 40);
      expect(restored.durationSeconds, isNull);
      expect(restored.enabled, isTrue);
      expect(restored.createdAt, timestamp);
      expect(restored.updatedAt, timestamp);
    });

    test('round trips short notification', () {
      final timestamp = DateTime.utc(2026, 9, 25, 12);

      final source = ShiftAlarm(
        id: 'alarm-2',
        phase: ShiftCyclePhase.day2,
        scope: ShiftAlarmScope.always,
        type: ShiftAlarmType.notification,
        title: 'Конец обеда',
        minutesOfDay: 13 * 60 + 10,
        durationSeconds: 15,
        enabled: false,
        createdAt: timestamp,
        updatedAt: timestamp,
      );

      final restored = ShiftAlarmMapper.fromMap(ShiftAlarmMapper.toMap(source));

      expect(restored.phase, ShiftCyclePhase.day2);
      expect(restored.scope, ShiftAlarmScope.always);
      expect(restored.type, ShiftAlarmType.notification);
      expect(restored.durationSeconds, 15);
      expect(restored.enabled, isFalse);
    });

    test('rejects unsupported schema version', () {
      expect(
        () => ShiftAlarmMapper.fromMap(<String, Object?>{'schemaVersion': 99}),
        throwsFormatException,
      );
    });

    test('rejects unknown phase', () {
      final map = _validMap();
      map['phase'] = 'unknownPhase';

      expect(() => ShiftAlarmMapper.fromMap(map), throwsFormatException);
    });

    test('rejects unknown scope', () {
      final map = _validMap();
      map['scope'] = 'sometimes';

      expect(() => ShiftAlarmMapper.fromMap(map), throwsFormatException);
    });

    test('rejects unknown type', () {
      final map = _validMap();
      map['type'] = 'timer';

      expect(() => ShiftAlarmMapper.fromMap(map), throwsFormatException);
    });

    test('rejects invalid notification duration', () {
      final map = _validMap();
      map['type'] = 'notification';
      map['durationSeconds'] = 25;

      expect(() => ShiftAlarmMapper.fromMap(map), throwsFormatException);
    });
  });
}

Map<String, Object?> _validMap() {
  return <String, Object?>{
    'schemaVersion': 1,
    'id': 'alarm-1',
    'phase': 'day1',
    'scope': 'work',
    'type': 'alarm',
    'title': 'Подъём',
    'minutesOfDay': 340,
    'durationSeconds': null,
    'enabled': true,
    'createdAt': 0,
    'updatedAt': 0,
  };
}
