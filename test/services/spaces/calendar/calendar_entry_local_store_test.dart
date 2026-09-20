import 'package:epistola/domain/models/calendar_entry.dart';
import 'package:epistola/services/spaces/calendar/calendar_entry_local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = CalendarEntryLocalStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('CalendarEntryLocalStore', () {
    test('returns empty list when user has no entries', () async {
      final entries = await store.loadForUser(userId: 'user-1');

      expect(entries, isEmpty);
    });

    test('saves and restores entry', () async {
      final entry = _task(id: 'entry-1', title: 'Спортзал');

      await store.save(userId: 'user-1', entry: entry);

      final restored = await store.loadForUser(userId: 'user-1');

      expect(restored, hasLength(1));
      expect(restored.single.id, 'entry-1');
      expect(restored.single.title, 'Спортзал');
      expect(restored.single.scheduledMinutes, 19 * 60);
      expect(restored.single.reminderMinutes, 18 * 60 + 30);
    });

    test('updates existing entry instead of duplicating it', () async {
      await store.save(
        userId: 'user-1',
        entry: _task(id: 'entry-1', title: 'Старое название'),
      );

      await store.save(
        userId: 'user-1',
        entry: _task(id: 'entry-1', title: 'Новое название'),
      );

      final restored = await store.loadForUser(userId: 'user-1');

      expect(restored, hasLength(1));
      expect(restored.single.title, 'Новое название');
    });

    test('keeps different users isolated', () async {
      await store.save(
        userId: 'user-1',
        entry: _task(id: 'entry-1', title: 'Первый пользователь'),
      );

      await store.save(
        userId: 'user-2',
        entry: _task(id: 'entry-2', title: 'Второй пользователь'),
      );

      final firstUserEntries = await store.loadForUser(userId: 'user-1');

      final secondUserEntries = await store.loadForUser(userId: 'user-2');

      expect(firstUserEntries, hasLength(1));
      expect(firstUserEntries.single.title, 'Первый пользователь');

      expect(secondUserEntries, hasLength(1));
      expect(secondUserEntries.single.title, 'Второй пользователь');
    });

    test('deletes entry without touching other entries', () async {
      await store.save(
        userId: 'user-1',
        entry: _task(id: 'entry-1', title: 'Первое'),
      );

      await store.save(
        userId: 'user-1',
        entry: _task(id: 'entry-2', title: 'Второе'),
      );

      await store.delete(userId: 'user-1', entryId: 'entry-1');

      final restored = await store.loadForUser(userId: 'user-1');

      expect(restored, hasLength(1));
      expect(restored.single.id, 'entry-2');
    });

    test('delete of missing entry is harmless', () async {
      await store.save(
        userId: 'user-1',
        entry: _task(id: 'entry-1', title: 'Дело'),
      );

      await store.delete(userId: 'user-1', entryId: 'missing-entry');

      final restored = await store.loadForUser(userId: 'user-1');

      expect(restored, hasLength(1));
      expect(restored.single.id, 'entry-1');
    });

    test('rejects empty user id', () async {
      expect(() => store.loadForUser(userId: '   '), throwsArgumentError);
    });
  });
}

CalendarEntry _task({required String id, required String title}) {
  return CalendarEntry(
    id: id,
    kind: CalendarEntryKind.task,
    date: DateTime(2026, 9, 20),
    title: title,
    scheduledMinutes: 19 * 60,
    reminderMinutes: 18 * 60 + 30,
    priority: CalendarEntryPriority.high,
    createdAt: DateTime.utc(2026, 9, 20, 10),
    updatedAt: DateTime.utc(2026, 9, 20, 10),
  );
}
