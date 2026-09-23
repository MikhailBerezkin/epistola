import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/shift_cycle.dart';
import '../../models/app_user.dart';

typedef AssignedCrewWatcher =
    Stream<ShiftCrew?> Function({required String userId});

final class UserAssignedCrewReader {
  UserAssignedCrewReader({required AssignedCrewWatcher assignedCrewWatcher})
    : _watchAssignedCrew = assignedCrewWatcher;

  factory UserAssignedCrewReader.firebase({FirebaseFirestore? firestore}) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    return UserAssignedCrewReader(
      assignedCrewWatcher: ({required String userId}) {
        return resolvedFirestore
            .collection('users')
            .doc(userId)
            .snapshots()
            .map((snapshot) => AppUser.fromFirestore(snapshot).assignedCrew);
      },
    );
  }

  final AssignedCrewWatcher _watchAssignedCrew;

  Stream<ShiftCrew?> watch({required String userId}) {
    return _watchAssignedCrew(userId: _normalizeUserId(userId));
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
