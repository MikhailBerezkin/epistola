import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubstitutionAvailability.tryParse', () {
    test('parses supported values', () {
      expect(
        SubstitutionAvailability.tryParse('green'),
        SubstitutionAvailability.green,
      );
      expect(
        SubstitutionAvailability.tryParse('yellow'),
        SubstitutionAvailability.yellow,
      );
      expect(
        SubstitutionAvailability.tryParse('red'),
        SubstitutionAvailability.red,
      );
    });

    test('rejects unsupported values', () {
      expect(SubstitutionAvailability.tryParse('unknown'), isNull);
      expect(SubstitutionAvailability.tryParse(''), isNull);
      expect(SubstitutionAvailability.tryParse(null), isNull);
      expect(SubstitutionAvailability.tryParse(1), isNull);
    });
  });

  group('SubstitutionParticipantStatus.tryParse', () {
    test('parses supported values', () {
      expect(
        SubstitutionParticipantStatus.tryParse('active'),
        SubstitutionParticipantStatus.active,
      );
      expect(
        SubstitutionParticipantStatus.tryParse('vacation'),
        SubstitutionParticipantStatus.vacation,
      );
      expect(
        SubstitutionParticipantStatus.tryParse('sick'),
        SubstitutionParticipantStatus.sick,
      );
    });

    test('rejects unsupported values', () {
      expect(SubstitutionParticipantStatus.tryParse('unknown'), isNull);
      expect(SubstitutionParticipantStatus.tryParse(''), isNull);
      expect(SubstitutionParticipantStatus.tryParse(null), isNull);
      expect(SubstitutionParticipantStatus.tryParse(1), isNull);
    });
  });

  group('SubstitutionParticipant', () {
    test('new participant is green and active by default', () {
      const participant = SubstitutionParticipant(
        userId: 'user-1',
        rotationOrder: 10,
      );

      expect(participant.availability, SubstitutionAvailability.green);
      expect(participant.status, SubstitutionParticipantStatus.active);
      expect(participant.isActive, isTrue);
      expect(participant.isOnVacation, isFalse);
      expect(participant.isSick, isFalse);
    });

    test('changing availability does not change rotation order', () {
      const participant = SubstitutionParticipant(
        userId: 'user-1',
        rotationOrder: 25,
      );

      final updated = participant.withAvailability(
        SubstitutionAvailability.red,
      );

      expect(updated.availability, SubstitutionAvailability.red);
      expect(updated.rotationOrder, 25);
      expect(updated.status, SubstitutionParticipantStatus.active);
    });

    test('moving to vacation preserves rotation order', () {
      const participant = SubstitutionParticipant(
        userId: 'user-1',
        rotationOrder: 25,
        availability: SubstitutionAvailability.yellow,
      );

      final updated = participant.withStatus(
        SubstitutionParticipantStatus.vacation,
      );

      expect(updated.status, SubstitutionParticipantStatus.vacation);
      expect(updated.rotationOrder, 25);
      expect(updated.availability, SubstitutionAvailability.yellow);
      expect(updated.isOnVacation, isTrue);
    });

    test('moving to sick preserves rotation order', () {
      const participant = SubstitutionParticipant(
        userId: 'user-1',
        rotationOrder: 25,
        availability: SubstitutionAvailability.red,
      );

      final updated = participant.withStatus(
        SubstitutionParticipantStatus.sick,
      );

      expect(updated.status, SubstitutionParticipantStatus.sick);
      expect(updated.rotationOrder, 25);
      expect(updated.availability, SubstitutionAvailability.red);
      expect(updated.isSick, isTrue);
    });

    test('returning from vacation preserves rotation order', () {
      const participant = SubstitutionParticipant(
        userId: 'user-1',
        rotationOrder: 25,
        status: SubstitutionParticipantStatus.vacation,
      );

      final updated = participant.withStatus(
        SubstitutionParticipantStatus.active,
      );

      expect(updated.status, SubstitutionParticipantStatus.active);
      expect(updated.rotationOrder, 25);
      expect(updated.isActive, isTrue);
    });

    test('returning from sick preserves rotation order', () {
      const participant = SubstitutionParticipant(
        userId: 'user-1',
        rotationOrder: 25,
        status: SubstitutionParticipantStatus.sick,
      );

      final updated = participant.withStatus(
        SubstitutionParticipantStatus.active,
      );

      expect(updated.status, SubstitutionParticipantStatus.active);
      expect(updated.rotationOrder, 25);
      expect(updated.isActive, isTrue);
    });
  });
}
