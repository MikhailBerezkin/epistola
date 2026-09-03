import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpacesBarMessageLifetime', () {
    test('parses supported storage values', () {
      expect(
        SpacesBarMessageLifetime.tryParse('oneHour'),
        SpacesBarMessageLifetime.oneHour,
      );
      expect(
        SpacesBarMessageLifetime.tryParse('twelveHours'),
        SpacesBarMessageLifetime.twelveHours,
      );
      expect(
        SpacesBarMessageLifetime.tryParse('twentyFourHours'),
        SpacesBarMessageLifetime.twentyFourHours,
      );
      expect(
        SpacesBarMessageLifetime.tryParse('untilCancelled'),
        SpacesBarMessageLifetime.untilCancelled,
      );
    });

    test('rejects unsupported storage values', () {
      expect(SpacesBarMessageLifetime.tryParse(''), isNull);
      expect(SpacesBarMessageLifetime.tryParse('forever'), isNull);
      expect(SpacesBarMessageLifetime.tryParse(null), isNull);
    });

    test('finite lifetimes calculate expiration', () {
      final createdAt = DateTime.utc(2026, 9, 3, 10);

      expect(
        SpacesBarMessageLifetime.oneHour.expiresAtFrom(createdAt),
        DateTime.utc(2026, 9, 3, 11),
      );
      expect(
        SpacesBarMessageLifetime.twelveHours.expiresAtFrom(createdAt),
        DateTime.utc(2026, 9, 3, 22),
      );
      expect(
        SpacesBarMessageLifetime.twentyFourHours.expiresAtFrom(createdAt),
        DateTime.utc(2026, 9, 4, 10),
      );
    });

    test('until cancelled has no expiration', () {
      final createdAt = DateTime.utc(2026, 9, 3, 10);

      expect(
        SpacesBarMessageLifetime.untilCancelled.expiresAtFrom(createdAt),
        isNull,
      );
    });
  });

  group('SpacesBarMessage', () {
    final createdAt = DateTime.utc(2026, 9, 3, 10);

    SpacesBarMessage createMessage({
      String id = 'message-1',
      String text = 'Закреплённое сообщение',
      SpacesBarMessageLifetime lifetime = SpacesBarMessageLifetime.twelveHours,
      String createdByUserId = 'brigadier-1',
    }) {
      return SpacesBarMessage.tryCreate(
        id: id,
        text: text,
        lifetime: lifetime,
        createdByUserId: createdByUserId,
        createdAt: createdAt,
      )!;
    }

    test('creates valid message', () {
      final message = createMessage();

      expect(message.id, 'message-1');
      expect(message.text, 'Закреплённое сообщение');
      expect(message.lifetime, SpacesBarMessageLifetime.twelveHours);
      expect(message.createdByUserId, 'brigadier-1');
      expect(message.createdAt, createdAt);
      expect(message.expiresAt, DateTime.utc(2026, 9, 3, 22));
    });

    test('trims persisted identity and text values', () {
      final message = createMessage(
        id: ' message-1 ',
        text: ' Сообщение ',
        createdByUserId: ' brigadier-1 ',
      );

      expect(message.id, 'message-1');
      expect(message.text, 'Сообщение');
      expect(message.createdByUserId, 'brigadier-1');
    });

    test('accepts exactly 250 characters', () {
      final message = SpacesBarMessage.tryCreate(
        id: 'message-1',
        text: 'а' * SpacesBarMessage.maxTextLength,
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdByUserId: 'brigadier-1',
        createdAt: createdAt,
      );

      expect(message, isNotNull);
    });

    test('rejects text longer than 250 characters', () {
      final message = SpacesBarMessage.tryCreate(
        id: 'message-1',
        text: 'а' * (SpacesBarMessage.maxTextLength + 1),
        lifetime: SpacesBarMessageLifetime.oneHour,
        createdByUserId: 'brigadier-1',
        createdAt: createdAt,
      );

      expect(message, isNull);
    });

    test('rejects empty required values', () {
      expect(
        SpacesBarMessage.tryCreate(
          id: '',
          text: 'Сообщение',
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdByUserId: 'brigadier-1',
          createdAt: createdAt,
        ),
        isNull,
      );

      expect(
        SpacesBarMessage.tryCreate(
          id: 'message-1',
          text: '   ',
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdByUserId: 'brigadier-1',
          createdAt: createdAt,
        ),
        isNull,
      );

      expect(
        SpacesBarMessage.tryCreate(
          id: 'message-1',
          text: 'Сообщение',
          lifetime: SpacesBarMessageLifetime.oneHour,
          createdByUserId: '   ',
          createdAt: createdAt,
        ),
        isNull,
      );
    });

    test('finite message becomes inactive at expiration', () {
      final message = createMessage(lifetime: SpacesBarMessageLifetime.oneHour);

      expect(
        message.isActiveAt(
          createdAt.add(const Duration(minutes: 59, seconds: 59)),
        ),
        isTrue,
      );

      expect(
        message.isActiveAt(createdAt.add(const Duration(hours: 1))),
        isFalse,
      );
    });

    test('until cancelled message does not expire by time', () {
      final message = createMessage(
        lifetime: SpacesBarMessageLifetime.untilCancelled,
      );

      expect(message.expiresAt, isNull);
      expect(
        message.isActiveAt(createdAt.add(const Duration(days: 365))),
        isTrue,
      );
    });
  });
}
