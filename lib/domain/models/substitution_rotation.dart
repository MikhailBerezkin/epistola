import 'substitution_participant.dart';

class SubstitutionRotationMove {
  final List<SubstitutionParticipant> participants;
  final String userId;
  final int previousRotationOrder;

  const SubstitutionRotationMove({
    required this.participants,
    required this.userId,
    required this.previousRotationOrder,
  });
}

class SubstitutionRotationAddition {
  final List<SubstitutionParticipant> participants;
  final int addedCount;
  final Set<String> createdUserIds;
  final Set<String> restoredUserIds;

  const SubstitutionRotationAddition({
    required this.participants,
    required this.addedCount,
    required this.createdUserIds,
    required this.restoredUserIds,
  });
}

class SubstitutionRotation {
  const SubstitutionRotation._();

  static List<SubstitutionParticipant> ordered(
    Iterable<SubstitutionParticipant> participants,
  ) {
    final result = participants.toList()
      ..sort((left, right) {
        final orderCompare = left.rotationOrder.compareTo(right.rotationOrder);

        if (orderCompare != 0) {
          return orderCompare;
        }

        return left.userId.compareTo(right.userId);
      });

    return result;
  }

  static List<SubstitutionParticipant> active(
    Iterable<SubstitutionParticipant> participants,
  ) {
    return ordered(participants.where((participant) => participant.isActive));
  }

  static int nextRotationOrder(Iterable<SubstitutionParticipant> participants) {
    var maxOrder = -1;

    for (final participant in participants) {
      if (participant.rotationOrder > maxOrder) {
        maxOrder = participant.rotationOrder;
      }
    }

    return maxOrder + 1;
  }

  static SubstitutionRotationAddition addOrRestoreParticipants({
    required Iterable<SubstitutionParticipant> participants,
    required Iterable<String> userIds,
  }) {
    final current = ordered(participants);

    final participantsById = <String, SubstitutionParticipant>{
      for (final participant in current) participant.userId: participant,
    };

    final requestedUserIds = <String>[];
    final seenUserIds = <String>{};

    for (final rawUserId in userIds) {
      final userId = rawUserId.trim();

      if (userId.isEmpty || userId.contains('/')) {
        throw ArgumentError.value(
          rawUserId,
          'userIds',
          'Each user id must be non-empty and must not contain slashes.',
        );
      }

      if (seenUserIds.add(userId)) {
        requestedUserIds.add(userId);
      }
    }

    final newUserIds = <String>[];
    final restoredUserIds = <String>{};

    for (final userId in requestedUserIds) {
      final existing = participantsById[userId];

      if (existing == null) {
        newUserIds.add(userId);
        continue;
      }

      if (existing.isRemoved) {
        restoredUserIds.add(userId);
      }
    }

    final newCount = newUserIds.length;

    final result = <SubstitutionParticipant>[];

    for (var index = 0; index < newUserIds.length; index++) {
      result.add(
        SubstitutionParticipant(
          userId: newUserIds[index],
          rotationOrder: index,
        ),
      );
    }

    for (final participant in current) {
      final shiftedParticipant = newCount == 0
          ? participant
          : participant.copyWith(
              rotationOrder: participant.rotationOrder + newCount,
            );

      if (restoredUserIds.contains(participant.userId)) {
        result.add(
          shiftedParticipant.withStatus(SubstitutionParticipantStatus.active),
        );
      } else {
        result.add(shiftedParticipant);
      }
    }

    return SubstitutionRotationAddition(
      participants: ordered(result),
      addedCount: newUserIds.length + restoredUserIds.length,
      createdUserIds: Set<String>.unmodifiable(newUserIds),
      restoredUserIds: Set<String>.unmodifiable(restoredUserIds),
    );
  }

  static SubstitutionRotationMove callParticipant({
    required Iterable<SubstitutionParticipant> participants,
    required String userId,
  }) {
    final current = participants.toList();

    final index = current.indexWhere(
      (participant) => participant.userId == userId,
    );

    if (index == -1) {
      throw ArgumentError.value(
        userId,
        'userId',
        'Participant is not in the substitution rotation',
      );
    }

    final participant = current[index];

    if (!participant.isActive) {
      throw StateError('Only an active participant can be called');
    }

    final previousRotationOrder = participant.rotationOrder;

    current[index] = participant.copyWith(
      rotationOrder: nextRotationOrder(current),
    );

    return SubstitutionRotationMove(
      participants: ordered(current),
      userId: userId,
      previousRotationOrder: previousRotationOrder,
    );
  }

  static List<SubstitutionParticipant> undoCall(SubstitutionRotationMove move) {
    final current = move.participants.toList();

    final index = current.indexWhere(
      (participant) => participant.userId == move.userId,
    );

    if (index == -1) {
      throw StateError('Called participant is missing from rotation');
    }

    current[index] = current[index].copyWith(
      rotationOrder: move.previousRotationOrder,
    );

    return ordered(current);
  }

  static List<SubstitutionParticipant> moveCalledParticipantToEnd({
    required Iterable<SubstitutionParticipant> participants,
    required String userId,
  }) {
    return callParticipant(
      participants: participants,
      userId: userId,
    ).participants;
  }
}
