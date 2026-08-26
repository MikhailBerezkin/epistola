import 'package:epistola/domain/models/substitution_participant.dart';
import 'package:epistola/services/spaces/substitution/substitution_participant_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubstitutionParticipantMapper.fromMap', () {
    test('parses valid participant data', () {
      final participant = SubstitutionParticipantMapper.fromMap(
        userId: 'user-1',
        data: const {
          'rotationOrder': 25,
          'availability': 'yellow',
          'status': 'vacation',
        },
      );

      expect(participant, isNotNull);
      expect(participant!.userId, 'user-1');
      expect(participant.rotationOrder, 25);
      expect(participant.availability, SubstitutionAvailability.yellow);
      expect(participant.status, SubstitutionParticipantStatus.vacation);
    });

    test('trims user id', () {
      final participant = SubstitutionParticipantMapper.fromMap(
        userId: '  user-1  ',
        data: const {
          'rotationOrder': 10,
          'availability': 'green',
          'status': 'active',
        },
      );

      expect(participant, isNotNull);
      expect(participant!.userId, 'user-1');
    });

    test('rejects empty user id', () {
      final participant = SubstitutionParticipantMapper.fromMap(
        userId: '   ',
        data: const {
          'rotationOrder': 10,
          'availability': 'green',
          'status': 'active',
        },
      );

      expect(participant, isNull);
    });

    test('rejects user id containing slash', () {
      final participant = SubstitutionParticipantMapper.fromMap(
        userId: 'user/1',
        data: const {
          'rotationOrder': 10,
          'availability': 'green',
          'status': 'active',
        },
      );

      expect(participant, isNull);
    });

    test('rejects missing rotation order', () {
      final participant = SubstitutionParticipantMapper.fromMap(
        userId: 'user-1',
        data: const {'availability': 'green', 'status': 'active'},
      );

      expect(participant, isNull);
    });

    test('rejects negative rotation order', () {
      final participant = SubstitutionParticipantMapper.fromMap(
        userId: 'user-1',
        data: const {
          'rotationOrder': -1,
          'availability': 'green',
          'status': 'active',
        },
      );

      expect(participant, isNull);
    });

    test('rejects unsupported availability', () {
      final participant = SubstitutionParticipantMapper.fromMap(
        userId: 'user-1',
        data: const {
          'rotationOrder': 10,
          'availability': 'blue',
          'status': 'active',
        },
      );

      expect(participant, isNull);
    });

    test('rejects unsupported status', () {
      final participant = SubstitutionParticipantMapper.fromMap(
        userId: 'user-1',
        data: const {
          'rotationOrder': 10,
          'availability': 'green',
          'status': 'removed',
        },
      );

      expect(participant, isNull);
    });
  });

  group('SubstitutionParticipantMapper.toMap', () {
    test('writes only substitution-owned fields', () {
      const participant = SubstitutionParticipant(
        userId: 'user-1',
        rotationOrder: 42,
        availability: SubstitutionAvailability.red,
        status: SubstitutionParticipantStatus.sick,
      );

      final data = SubstitutionParticipantMapper.toMap(participant);

      expect(data, const {
        'rotationOrder': 42,
        'availability': 'red',
        'status': 'sick',
      });

      expect(data.containsKey('userId'), isFalse);
      expect(data.containsKey('name'), isFalse);
      expect(data.containsKey('email'), isFalse);
      expect(data.containsKey('avatarUrl'), isFalse);
    });

    test('new participant default state persists as green and active', () {
      const participant = SubstitutionParticipant(
        userId: 'user-1',
        rotationOrder: 0,
      );

      final data = SubstitutionParticipantMapper.toMap(participant);

      expect(data['availability'], 'green');
      expect(data['status'], 'active');
    });
  });
}
