import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/app_user.dart';

typedef SubstitutionCandidatesLoader = Future<List<AppUser>> Function();

final class SubstitutionCandidatesService {
  SubstitutionCandidatesService({
    required SubstitutionCandidatesLoader candidatesLoader,
  }) : _loadCandidates = candidatesLoader;

  factory SubstitutionCandidatesService.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    return SubstitutionCandidatesService(
      candidatesLoader: () async {
        final snapshot = await resolvedFirestore.collection('users').get();

        return snapshot.docs
            .map(AppUser.fromFirestore)
            .where((user) => user.uid.trim().isNotEmpty)
            .toList(growable: false);
      },
    );
  }

  final SubstitutionCandidatesLoader _loadCandidates;

  Future<List<AppUser>> loadCandidates({
    Iterable<String> excludedUserIds = const <String>[],
  }) async {
    final excludedIds = excludedUserIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet();

    final users = await _loadCandidates();

    final candidates = users
        .where((user) => !excludedIds.contains(user.uid.trim()))
        .toList();

    candidates.sort((left, right) {
      final leftName = _displayName(left).toLowerCase();
      final rightName = _displayName(right).toLowerCase();

      final nameComparison = leftName.compareTo(rightName);

      if (nameComparison != 0) {
        return nameComparison;
      }

      return left.uid.compareTo(right.uid);
    });

    return List<AppUser>.unmodifiable(candidates);
  }

  static String _displayName(AppUser user) {
    final displayName = user.effectiveWorkDisplayName.trim();

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email.trim();

    if (email.isNotEmpty) {
      return email;
    }

    return user.uid.trim();
  }
}
