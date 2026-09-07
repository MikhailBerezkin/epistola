import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_participant.dart';
import '../../../domain/models/substitution_rotation.dart';
import 'substitution_participant_mapper.dart';
import 'substitution_rotation_membership_firestore_gateway.dart';

typedef SubstitutionParticipantsWatcher =
    Stream<List<SubstitutionParticipant>> Function();

typedef SubstitutionParticipantsAdder =
    Future<int> Function(List<String> userIds);

final class SubstitutionParticipantsService {
  SubstitutionParticipantsService({
    required SubstitutionParticipantsWatcher participantsWatcher,
    required SubstitutionParticipantsAdder participantsAdder,
  }) : _watchParticipants = participantsWatcher,
       _addParticipants = participantsAdder;

  factory SubstitutionParticipantsService.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final moduleReference = resolvedFirestore
        .collection('spaces')
        .doc('substitution');

    final participantsReference = moduleReference.collection('participants');

    final participantsGateway =
        SubstitutionRotationMembershipFirestoreGateway.firebase(
          firestore: resolvedFirestore,
        );

    return SubstitutionParticipantsService(
      participantsWatcher: () {
        return participantsReference
            .orderBy(SubstitutionParticipantMapper.rotationOrderField)
            .snapshots()
            .map((snapshot) {
              final participants = <SubstitutionParticipant>[];

              for (final document in snapshot.docs) {
                final participant = SubstitutionParticipantMapper.fromMap(
                  userId: document.id,
                  data: document.data(),
                );

                if (participant != null) {
                  participants.add(participant);
                }
              }

              return participants;
            });
      },
      participantsAdder: participantsGateway.addParticipants,
    );
  }

  final SubstitutionParticipantsWatcher _watchParticipants;
  final SubstitutionParticipantsAdder _addParticipants;

  Stream<List<SubstitutionParticipant>> watchParticipants() {
    return _watchParticipants().map(SubstitutionRotation.ordered);
  }

  Future<int> addParticipants(Iterable<String> userIds) {
    final normalizedUserIds = <String>[];
    final seenUserIds = <String>{};

    for (final rawUserId in userIds) {
      final userId = rawUserId.trim();

      if (!_isValidIdentifier(userId)) {
        throw ArgumentError.value(
          rawUserId,
          'userIds',
          'Each user id must be non-empty '
              'and must not contain slashes.',
        );
      }

      if (seenUserIds.add(userId)) {
        normalizedUserIds.add(userId);
      }
    }

    if (normalizedUserIds.isEmpty) {
      return Future.value(0);
    }

    return _addParticipants(normalizedUserIds);
  }

  static bool _isValidIdentifier(String value) {
    return value.isNotEmpty && value == value.trim() && !value.contains('/');
  }
}
