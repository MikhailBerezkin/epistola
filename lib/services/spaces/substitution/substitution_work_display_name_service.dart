typedef SubstitutionWorkDisplayNameWriter =
    Future<void> Function({
      required String userId,
      required String workDisplayName,
    });

final class SubstitutionWorkDisplayNameService {
  SubstitutionWorkDisplayNameService({
    required SubstitutionWorkDisplayNameWriter workDisplayNameWriter,
  }) : _writeWorkDisplayName = workDisplayNameWriter;

  static const int maxWorkDisplayNameLength = 80;

  final SubstitutionWorkDisplayNameWriter _writeWorkDisplayName;

  Future<void> updateWorkDisplayName({
    required String userId,
    required String workDisplayName,
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

    return _writeWorkDisplayName(
      userId: _normalizeUserId(userId),
      workDisplayName: normalizedName,
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
