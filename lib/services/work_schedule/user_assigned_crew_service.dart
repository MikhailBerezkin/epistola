import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/shift_cycle.dart';

typedef AssignedCrewWriter =
    Future<void> Function({required String userId, required int crewNumber});

final class UserAssignedCrewService {
  UserAssignedCrewService({required AssignedCrewWriter assignedCrewWriter})
    : _writeAssignedCrew = assignedCrewWriter;

  factory UserAssignedCrewService.firebase({FirebaseFirestore? firestore}) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    return UserAssignedCrewService(
      assignedCrewWriter: ({required String userId, required int crewNumber}) {
        return resolvedFirestore.collection('users').doc(userId).update({
          'assignedCrew': crewNumber,
        });
      },
    );
  }

  final AssignedCrewWriter _writeAssignedCrew;

  Future<void> selectInitialCrew({
    required String userId,
    required ShiftCrew crew,
  }) {
    return _write(userId: userId, crew: crew);
  }

  Future<void> correctCrewAsManager({
    required String userId,
    required ShiftCrew crew,
  }) {
    return _write(userId: userId, crew: crew);
  }

  Future<void> _write({required String userId, required ShiftCrew crew}) {
    return _writeAssignedCrew(
      userId: _normalizeUserId(userId),
      crewNumber: crew.number,
    );
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
