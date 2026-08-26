import '../../../domain/models/substitution_participant.dart';

typedef SubstitutionParticipantAvailabilityWriter =
    Future<void> Function({
      required String userId,
      required SubstitutionAvailability availability,
    });

typedef SubstitutionParticipantStatusWriter =
    Future<void> Function({
      required String userId,
      required SubstitutionParticipantStatus status,
    });

typedef SubstitutionParticipantRemover =
    Future<void> Function({required String userId});

final class SubstitutionParticipantActionsService {
  SubstitutionParticipantActionsService({
    required SubstitutionParticipantAvailabilityWriter availabilityWriter,
    required SubstitutionParticipantStatusWriter statusWriter,
    required SubstitutionParticipantRemover participantRemover,
  }) : _writeAvailability = availabilityWriter,
       _writeStatus = statusWriter,
       _removeParticipant = participantRemover;

  final SubstitutionParticipantAvailabilityWriter _writeAvailability;
  final SubstitutionParticipantStatusWriter _writeStatus;
  final SubstitutionParticipantRemover _removeParticipant;

  Future<void> updateAvailability({
    required String userId,
    required SubstitutionAvailability availability,
  }) {
    return _writeAvailability(
      userId: _normalizeUserId(userId),
      availability: availability,
    );
  }

  Future<void> updateStatus({
    required String userId,
    required SubstitutionParticipantStatus status,
  }) {
    return _writeStatus(userId: _normalizeUserId(userId), status: status);
  }

  Future<void> removeParticipant({required String userId}) {
    return _removeParticipant(userId: _normalizeUserId(userId));
  }

  static String _normalizeUserId(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(
        value,
        'userId',
        'userId must be non-empty and must not contain slashes.',
      );
    }

    return normalized;
  }
}
