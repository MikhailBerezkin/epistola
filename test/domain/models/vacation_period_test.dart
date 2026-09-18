import 'package:epistola/domain/models/vacation_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VacationPeriod', () {
    test('accepts inclusive date range', () {
      final period = VacationPeriod(
        userId: 'user-1',
        slot: 1,
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 10, 18),
      );

      expect(period.contains(DateTime(2026, 10, 5)), isTrue);
      expect(period.contains(DateTime(2026, 10, 18)), isTrue);
      expect(period.contains(DateTime(2026, 10, 4)), isFalse);
      expect(period.contains(DateTime(2026, 10, 19)), isFalse);
    });

    test('ignores time of day', () {
      final period = VacationPeriod(
        userId: 'user-1',
        slot: 2,
        startDate: DateTime(2026, 10, 5, 23, 30),
        endDate: DateTime(2026, 10, 18, 1, 15),
      );

      expect(period.contains(DateTime(2026, 10, 5, 0, 1)), isTrue);

      expect(period.contains(DateTime(2026, 10, 18, 23, 59)), isTrue);
    });

    test('builds deterministic document id', () {
      final period = VacationPeriod(
        userId: ' user-1 ',
        slot: 6,
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 10, 18),
      );

      expect(period.documentId, 'user-1__6');
    });

    test('rejects slot outside one to six', () {
      final period = VacationPeriod(
        userId: 'user-1',
        slot: 7,
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 10, 18),
      );

      expect(period.isValid, isFalse);
    });

    test('rejects reversed range', () {
      final period = VacationPeriod(
        userId: 'user-1',
        slot: 1,
        startDate: DateTime(2026, 10, 18),
        endDate: DateTime(2026, 10, 5),
      );

      expect(period.isValid, isFalse);
    });
  });
}
