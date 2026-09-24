import '../../../domain/models/shift_cycle.dart';

typedef SubstitutionWorkProfileWriter =
    Future<void> Function({
      required String userId,
      required String workDisplayName,
      required int crewNumber,
    });

final class SubstitutionWorkProfileService {
  SubstitutionWorkProfileService({
    required SubstitutionWorkProfileWriter workProfileWriter,
  }) : _writeWorkProfile = workProfileWriter;

  static const int maxWorkDisplayNameLength = 80;

  final SubstitutionWorkProfileWriter _writeWorkProfile;

  Future<void> updateWorkProfile({
    required String userId,
    required String workDisplayName,
    required ShiftCrew crew,
  }) {
    final normalizedName = workDisplayName.trim();

    if (normalizedName.length > maxWorkDisplayNameLength) {
      throw ArgumentError.value(
        workDisplayName,
        'workDisplayName',
        'workDisplayName must not exceed '
            '$maxWorkDisplayNameLength characters.',
      );
    }

    return _writeWorkProfile(
      userId: _normalizeUserId(userId),
      workDisplayName: normalizedName,
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
