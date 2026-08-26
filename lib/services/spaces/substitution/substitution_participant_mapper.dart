import '../../../domain/models/substitution_participant.dart';

final class SubstitutionParticipantMapper {
  const SubstitutionParticipantMapper._();

  static const String rotationOrderField = 'rotationOrder';
  static const String availabilityField = 'availability';
  static const String statusField = 'status';

  static SubstitutionParticipant? fromMap({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty || normalizedUserId.contains('/')) {
      return null;
    }

    final rotationOrder = data[rotationOrderField];

    if (rotationOrder is! int || rotationOrder < 0) {
      return null;
    }

    final availability = SubstitutionAvailability.tryParse(
      data[availabilityField],
    );

    final status = SubstitutionParticipantStatus.tryParse(data[statusField]);

    if (availability == null || status == null) {
      return null;
    }

    return SubstitutionParticipant(
      userId: normalizedUserId,
      rotationOrder: rotationOrder,
      availability: availability,
      status: status,
    );
  }

  static Map<String, dynamic> toMap(SubstitutionParticipant participant) {
    return <String, dynamic>{
      rotationOrderField: participant.rotationOrder,
      availabilityField: participant.availability.storageValue,
      statusField: participant.status.storageValue,
    };
  }
}
