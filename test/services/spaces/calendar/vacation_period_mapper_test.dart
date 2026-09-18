import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/vacation_period.dart';
import 'package:epistola/services/spaces/calendar/vacation_period_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VacationPeriodMapper', () {
    test('writes normalized vacation period', () {
      final period = VacationPeriod(
        userId: ' user-1 ',
        slot: 2,
        startDate: DateTime(2026, 10, 5, 23, 30),
        endDate: DateTime(2026, 10, 18, 1, 15),
      );

      final data = VacationPeriodMapper.toMap(period);

      expect(data['schemaVersion'], 1);
      expect(data['userId'], 'user-1');
      expect(data['slot'], 2);
      expect(data['startDay'], 20261005);
      expect(data['endDay'], 20261018);
      expect(data['updatedAt'], isA<FieldValue>());
    });

    test('reads valid vacation period', () {
      final period = VacationPeriodMapper.fromMap({
        'schemaVersion': 1,
        'userId': 'user-1',
        'slot': 6,
        'startDay': 20261005,
        'endDay': 20261018,
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 17, 12)),
      });

      expect(period, isNotNull);
      expect(period?.userId, 'user-1');
      expect(period?.slot, 6);
      expect(period?.startDate, DateTime.utc(2026, 10, 5));
      expect(period?.endDate, DateTime.utc(2026, 10, 18));
      expect(period?.documentId, 'user-1__6');
    });

    test('rejects reversed vacation range', () {
      final period = VacationPeriodMapper.fromMap({
        'schemaVersion': 1,
        'userId': 'user-1',
        'slot': 1,
        'startDay': 20261018,
        'endDay': 20261005,
        'updatedAt': Timestamp.now(),
      });

      expect(period, isNull);
    });

    test('rejects invalid calendar date', () {
      final period = VacationPeriodMapper.fromMap({
        'schemaVersion': 1,
        'userId': 'user-1',
        'slot': 1,
        'startDay': 20260230,
        'endDay': 20260305,
        'updatedAt': Timestamp.now(),
      });

      expect(period, isNull);
    });

    test('rejects slot outside one to six', () {
      final period = VacationPeriodMapper.fromMap({
        'schemaVersion': 1,
        'userId': 'user-1',
        'slot': 7,
        'startDay': 20261005,
        'endDay': 20261018,
        'updatedAt': Timestamp.now(),
      });

      expect(period, isNull);
    });

    test('rejects unexpected fields', () {
      final period = VacationPeriodMapper.fromMap({
        'schemaVersion': 1,
        'userId': 'user-1',
        'slot': 1,
        'startDay': 20261005,
        'endDay': 20261018,
        'updatedAt': Timestamp.now(),
        'unexpected': true,
      });

      expect(period, isNull);
    });
  });
}
