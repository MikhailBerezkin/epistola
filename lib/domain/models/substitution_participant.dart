enum SubstitutionAvailability {
  green('green'),
  yellow('yellow'),
  red('red');

  const SubstitutionAvailability(this.storageValue);

  final String storageValue;

  static SubstitutionAvailability? tryParse(Object? value) {
    return switch (value) {
      'green' => SubstitutionAvailability.green,
      'yellow' => SubstitutionAvailability.yellow,
      'red' => SubstitutionAvailability.red,
      _ => null,
    };
  }
}

enum SubstitutionParticipantStatus {
  active('active'),
  vacation('vacation'),
  sick('sick');

  const SubstitutionParticipantStatus(this.storageValue);

  final String storageValue;

  static SubstitutionParticipantStatus? tryParse(Object? value) {
    return switch (value) {
      'active' => SubstitutionParticipantStatus.active,
      'vacation' => SubstitutionParticipantStatus.vacation,
      'sick' => SubstitutionParticipantStatus.sick,
      _ => null,
    };
  }
}

class SubstitutionParticipant {
  final String userId;
  final int rotationOrder;
  final SubstitutionAvailability availability;
  final SubstitutionParticipantStatus status;

  const SubstitutionParticipant({
    required this.userId,
    required this.rotationOrder,
    this.availability = SubstitutionAvailability.green,
    this.status = SubstitutionParticipantStatus.active,
  }) : assert(userId != ''),
       assert(rotationOrder >= 0);

  bool get isActive => status == SubstitutionParticipantStatus.active;

  bool get isOnVacation => status == SubstitutionParticipantStatus.vacation;

  bool get isSick => status == SubstitutionParticipantStatus.sick;

  SubstitutionParticipant withAvailability(
    SubstitutionAvailability availability,
  ) {
    return copyWith(availability: availability);
  }

  SubstitutionParticipant withStatus(SubstitutionParticipantStatus status) {
    return copyWith(status: status);
  }

  SubstitutionParticipant copyWith({
    String? userId,
    int? rotationOrder,
    SubstitutionAvailability? availability,
    SubstitutionParticipantStatus? status,
  }) {
    return SubstitutionParticipant(
      userId: userId ?? this.userId,
      rotationOrder: rotationOrder ?? this.rotationOrder,
      availability: availability ?? this.availability,
      status: status ?? this.status,
    );
  }
}
