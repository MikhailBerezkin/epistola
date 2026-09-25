import 'package:epistola/domain/models/shift_alarm.dart';
import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShiftAlarm', () {
    test('accepts regular alarm without duration', () {
      final alarm = _alarm(type: ShiftAlarmType.alarm, durationSeconds: null);

      expect(alarm.isValid, isTrue);
      expect(alarm.isAlarm, isTrue);
      expect(alarm.isNotification, isFalse);
    });

    test('rejects regular alarm with duration', () {
      final alarm = _alarm(type: ShiftAlarmType.alarm, durationSeconds: 15);

      expect(alarm.isValid, isFalse);
    });

    for (final duration in ShiftAlarm.allowedNotificationDurations) {
      test('accepts notification duration $duration seconds', () {
        final alarm = _alarm(
          type: ShiftAlarmType.notification,
          durationSeconds: duration,
        );

        expect(alarm.isValid, isTrue);
        expect(alarm.isNotification, isTrue);
      });
    }

    test('rejects notification without duration', () {
      final alarm = _alarm(
        type: ShiftAlarmType.notification,
        durationSeconds: null,
      );

      expect(alarm.isValid, isFalse);
    });

    test('rejects unsupported notification duration', () {
      final alarm = _alarm(
        type: ShiftAlarmType.notification,
        durationSeconds: 25,
      );

      expect(alarm.isValid, isFalse);
    });

    test('rejects empty title', () {
      final alarm = _alarm(title: '   ');

      expect(alarm.isValid, isFalse);
    });

    test('rejects empty id', () {
      final alarm = _alarm(id: '   ');

      expect(alarm.isValid, isFalse);
    });

    test('accepts first minute of day', () {
      final alarm = _alarm(minutesOfDay: 0);

      expect(alarm.isValid, isTrue);
    });

    test('accepts last minute of day', () {
      final alarm = _alarm(minutesOfDay: 23 * 60 + 59);

      expect(alarm.isValid, isTrue);
    });

    test('rejects negative minutes', () {
      final alarm = _alarm(minutesOfDay: -1);

      expect(alarm.isValid, isFalse);
    });

    test('rejects minutes outside day', () {
      final alarm = _alarm(minutesOfDay: 24 * 60);

      expect(alarm.isValid, isFalse);
    });

    test('rejects updatedAt before createdAt', () {
      final alarm = ShiftAlarm(
        id: 'alarm-1',
        phase: ShiftCyclePhase.day1,
        scope: ShiftAlarmScope.work,
        type: ShiftAlarmType.alarm,
        title: 'Подъём',
        minutesOfDay: 5 * 60 + 40,
        enabled: true,
        createdAt: DateTime.utc(2026, 9, 25, 12),
        updatedAt: DateTime.utc(2026, 9, 25, 11),
      );

      expect(alarm.isValid, isFalse);
    });

    test('copyWith can change editable fields', () {
      final original = _alarm(
        title: 'Конец обеда',
        type: ShiftAlarmType.notification,
        durationSeconds: 15,
      );

      final updated = original.copyWith(
        title: 'Конец обеда №1',
        minutesOfDay: 13 * 60 + 10,
        durationSeconds: 20,
        enabled: false,
      );

      expect(updated.title, 'Конец обеда №1');
      expect(updated.minutesOfDay, 13 * 60 + 10);
      expect(updated.durationSeconds, 20);
      expect(updated.enabled, isFalse);

      expect(updated.id, original.id);
      expect(updated.phase, original.phase);
      expect(updated.scope, original.scope);
      expect(updated.createdAt, original.createdAt);
    });

    test('copyWith can clear duration when changing to alarm', () {
      final original = _alarm(
        type: ShiftAlarmType.notification,
        durationSeconds: 15,
      );

      final updated = original.copyWith(
        type: ShiftAlarmType.alarm,
        durationSeconds: null,
      );

      expect(updated.type, ShiftAlarmType.alarm);
      expect(updated.durationSeconds, isNull);
      expect(updated.isValid, isTrue);
    });
  });

  group('ShiftAlarmScope', () {
    test('has expected presentation titles', () {
      expect(ShiftAlarmScope.work.displayTitle, 'Рабочие смены');
      expect(ShiftAlarmScope.always.displayTitle, 'Всегда');
      expect(ShiftAlarmScope.vacation.displayTitle, 'В отпуске');
    });
  });

  group('ShiftAlarmPhasePresentation', () {
    test('provides unique editor titles for all eight phases', () {
      final titles = ShiftCyclePhase.values
          .map((phase) => phase.alarmEditorTitle)
          .toList(growable: false);

      expect(titles, <String>[
        'День 1',
        'День 2',
        'Выходной',
        'Ночь 1',
        'Ночь 2',
        'Отсыпной',
        'Выходной 1',
        'Выходной 2',
      ]);

      expect(titles.toSet(), hasLength(8));
    });
  });
}

ShiftAlarm _alarm({
  String id = 'alarm-1',
  ShiftCyclePhase phase = ShiftCyclePhase.day1,
  ShiftAlarmScope scope = ShiftAlarmScope.work,
  ShiftAlarmType type = ShiftAlarmType.alarm,
  String title = 'Подъём',
  int minutesOfDay = 5 * 60 + 40,
  int? durationSeconds,
  bool enabled = true,
}) {
  final timestamp = DateTime.utc(2026, 9, 25, 12);

  return ShiftAlarm(
    id: id,
    phase: phase,
    scope: scope,
    type: type,
    title: title,
    minutesOfDay: minutesOfDay,
    durationSeconds: durationSeconds,
    enabled: enabled,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
