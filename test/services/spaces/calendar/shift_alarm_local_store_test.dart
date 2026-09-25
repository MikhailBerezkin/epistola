import 'package:epistola/domain/models/shift_alarm.dart';
import 'package:epistola/domain/models/shift_cycle.dart';
import 'package:epistola/services/spaces/calendar/shift_alarm_local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = ShiftAlarmLocalStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ShiftAlarmLocalStore', () {
    test('returns empty list when user has no alarms', () async {
      final alarms = await store.loadForUser(userId: 'user-1');

      expect(alarms, isEmpty);
    });

    test('saves and restores regular alarm', () async {
      final alarm = _alarm(id: 'alarm-1', title: 'Подъём');

      await store.save(userId: 'user-1', alarm: alarm);

      final restored = await store.loadForUser(userId: 'user-1');

      expect(restored, hasLength(1));
      expect(restored.single.id, 'alarm-1');
      expect(restored.single.title, 'Подъём');
      expect(restored.single.phase, ShiftCyclePhase.day1);
      expect(restored.single.scope, ShiftAlarmScope.work);
      expect(restored.single.type, ShiftAlarmType.alarm);
    });

    test('saves short notification', () async {
      final alarm = _alarm(
        id: 'notification-1',
        title: 'Конец обеда',
        type: ShiftAlarmType.notification,
        durationSeconds: 15,
      );

      await store.save(userId: 'user-1', alarm: alarm);

      final restored = await store.loadForUser(userId: 'user-1');

      expect(restored.single.type, ShiftAlarmType.notification);
      expect(restored.single.durationSeconds, 15);
    });

    test('updates existing alarm instead of duplicating it', () async {
      await store.save(
        userId: 'user-1',
        alarm: _alarm(id: 'alarm-1', title: 'Старое название'),
      );

      await store.save(
        userId: 'user-1',
        alarm: _alarm(id: 'alarm-1', title: 'Новое название', enabled: false),
      );

      final restored = await store.loadForUser(userId: 'user-1');

      expect(restored, hasLength(1));
      expect(restored.single.title, 'Новое название');
      expect(restored.single.enabled, isFalse);
    });

    test('keeps different users isolated', () async {
      await store.save(
        userId: 'user-1',
        alarm: _alarm(id: 'alarm-1', title: 'Первый пользователь'),
      );

      await store.save(
        userId: 'user-2',
        alarm: _alarm(id: 'alarm-2', title: 'Второй пользователь'),
      );

      final firstUserAlarms = await store.loadForUser(userId: 'user-1');

      final secondUserAlarms = await store.loadForUser(userId: 'user-2');

      expect(firstUserAlarms, hasLength(1));
      expect(firstUserAlarms.single.title, 'Первый пользователь');

      expect(secondUserAlarms, hasLength(1));
      expect(secondUserAlarms.single.title, 'Второй пользователь');
    });

    test('stores alarms from different phases and scopes', () async {
      await store.save(
        userId: 'user-1',
        alarm: _alarm(
          id: 'day-alarm',
          phase: ShiftCyclePhase.day1,
          scope: ShiftAlarmScope.work,
        ),
      );

      await store.save(
        userId: 'user-1',
        alarm: _alarm(
          id: 'night-alarm',
          phase: ShiftCyclePhase.night1,
          scope: ShiftAlarmScope.always,
        ),
      );

      final restored = await store.loadForUser(userId: 'user-1');

      expect(restored, hasLength(2));

      expect(
        restored.any(
          (alarm) =>
              alarm.phase == ShiftCyclePhase.day1 &&
              alarm.scope == ShiftAlarmScope.work,
        ),
        isTrue,
      );

      expect(
        restored.any(
          (alarm) =>
              alarm.phase == ShiftCyclePhase.night1 &&
              alarm.scope == ShiftAlarmScope.always,
        ),
        isTrue,
      );
    });

    test('deletes alarm without touching other alarms', () async {
      await store.save(
        userId: 'user-1',
        alarm: _alarm(id: 'alarm-1', title: 'Первый'),
      );

      await store.save(
        userId: 'user-1',
        alarm: _alarm(id: 'alarm-2', title: 'Второй'),
      );

      await store.delete(userId: 'user-1', alarmId: 'alarm-1');

      final restored = await store.loadForUser(userId: 'user-1');

      expect(restored, hasLength(1));
      expect(restored.single.id, 'alarm-2');
    });

    test('delete of missing alarm is harmless', () async {
      await store.save(
        userId: 'user-1',
        alarm: _alarm(id: 'alarm-1'),
      );

      await store.delete(userId: 'user-1', alarmId: 'missing-alarm');

      final restored = await store.loadForUser(userId: 'user-1');

      expect(restored, hasLength(1));
      expect(restored.single.id, 'alarm-1');
    });

    test('rejects empty user id', () async {
      expect(() => store.loadForUser(userId: '   '), throwsArgumentError);
    });

    test('rejects empty alarm id on delete', () async {
      expect(
        () => store.delete(userId: 'user-1', alarmId: '   '),
        throwsArgumentError,
      );
    });
  });
}

ShiftAlarm _alarm({
  required String id,
  String title = 'Подъём',
  ShiftCyclePhase phase = ShiftCyclePhase.day1,
  ShiftAlarmScope scope = ShiftAlarmScope.work,
  ShiftAlarmType type = ShiftAlarmType.alarm,
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
