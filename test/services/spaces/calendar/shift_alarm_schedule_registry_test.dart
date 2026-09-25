import 'package:epistola/services/spaces/calendar/shift_alarm_schedule_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const registry = ShiftAlarmScheduleRegistry();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ShiftAlarmScheduleRegistry', () {
    test('returns empty list for new user', () async {
      final items = await registry.loadForUser(userId: 'user-1');

      expect(items, isEmpty);
    });

    test('stores and restores scheduled items', () async {
      await registry.replaceForUser(
        userId: 'user-1',
        items: const <ShiftAlarmScheduledItem>[
          ShiftAlarmScheduledItem(
            occurrenceId: 'wake-up_20260929',
            notificationId: 1001,
          ),
          ShiftAlarmScheduledItem(
            occurrenceId: 'lunch_20260929',
            notificationId: 1002,
          ),
        ],
      );

      final restored = await registry.loadForUser(userId: 'user-1');

      expect(restored, hasLength(2));

      expect(restored[0].occurrenceId, 'wake-up_20260929');

      expect(restored[0].notificationId, 1001);

      expect(restored[1].occurrenceId, 'lunch_20260929');
    });

    test('replace removes old registry items', () async {
      await registry.replaceForUser(
        userId: 'user-1',
        items: const <ShiftAlarmScheduledItem>[
          ShiftAlarmScheduledItem(occurrenceId: 'old', notificationId: 1),
        ],
      );

      await registry.replaceForUser(
        userId: 'user-1',
        items: const <ShiftAlarmScheduledItem>[
          ShiftAlarmScheduledItem(occurrenceId: 'new', notificationId: 2),
        ],
      );

      final restored = await registry.loadForUser(userId: 'user-1');

      expect(restored, hasLength(1));
      expect(restored.single.occurrenceId, 'new');
      expect(restored.single.notificationId, 2);
    });

    test('keeps different users isolated', () async {
      await registry.replaceForUser(
        userId: 'user-1',
        items: const <ShiftAlarmScheduledItem>[
          ShiftAlarmScheduledItem(occurrenceId: 'first', notificationId: 1),
        ],
      );

      await registry.replaceForUser(
        userId: 'user-2',
        items: const <ShiftAlarmScheduledItem>[
          ShiftAlarmScheduledItem(occurrenceId: 'second', notificationId: 2),
        ],
      );

      final first = await registry.loadForUser(userId: 'user-1');

      final second = await registry.loadForUser(userId: 'user-2');

      expect(first.single.occurrenceId, 'first');
      expect(second.single.occurrenceId, 'second');
    });

    test('clear removes user registry', () async {
      await registry.replaceForUser(
        userId: 'user-1',
        items: const <ShiftAlarmScheduledItem>[
          ShiftAlarmScheduledItem(occurrenceId: 'alarm', notificationId: 42),
        ],
      );

      await registry.clearForUser(userId: 'user-1');

      final restored = await registry.loadForUser(userId: 'user-1');

      expect(restored, isEmpty);
    });

    test('rejects empty user id', () async {
      expect(() => registry.loadForUser(userId: '   '), throwsArgumentError);
    });

    test('rejects duplicate occurrence ids', () async {
      expect(
        () => registry.replaceForUser(
          userId: 'user-1',
          items: const <ShiftAlarmScheduledItem>[
            ShiftAlarmScheduledItem(occurrenceId: 'same', notificationId: 1),
            ShiftAlarmScheduledItem(occurrenceId: 'same', notificationId: 2),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid notification id', () async {
      expect(
        () => registry.replaceForUser(
          userId: 'user-1',
          items: const <ShiftAlarmScheduledItem>[
            ShiftAlarmScheduledItem(occurrenceId: 'alarm', notificationId: -1),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
