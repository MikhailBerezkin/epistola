import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/substitution_participant.dart';
import '../../../domain/models/substitution_rotation.dart';
import 'substitution_participant_mapper.dart';

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
      participantsAdder: (userIds) {
        return resolvedFirestore.runTransaction<int>((transaction) async {
          final moduleSnapshot = await transaction.get(moduleReference);

          final moduleData = moduleSnapshot.data();
          final storedNextOrder = moduleData?['nextRotationOrder'];

          var nextOrder = storedNextOrder is int && storedNextOrder >= 0
              ? storedNextOrder
              : 0;

          final participantReferences = userIds
              .map(participantsReference.doc)
              .toList(growable: false);

          final participantSnapshots =
              <DocumentSnapshot<Map<String, dynamic>>>[];

          // Firestore-транзакция сначала выполняет все чтения,
          // и только потом записи.
          for (final reference in participantReferences) {
            participantSnapshots.add(await transaction.get(reference));
          }

          var addedCount = 0;

          for (var index = 0; index < userIds.length; index++) {
            if (participantSnapshots[index].exists) {
              continue;
            }

            final participant = SubstitutionParticipant(
              userId: userIds[index],
              rotationOrder: nextOrder,
            );

            transaction.set(
              participantReferences[index],
              SubstitutionParticipantMapper.toMap(participant),
            );

            nextOrder++;
            addedCount++;
          }

          if (addedCount > 0) {
            transaction.set(moduleReference, <String, dynamic>{
              'nextRotationOrder': nextOrder,
            }, SetOptions(merge: true));
          }

          return addedCount;
        });
      },
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
          'Each user id must be non-empty and must not contain slashes.',
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
