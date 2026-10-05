abstract final class VesselPhotoPaths {
  static String vesselKey({required String vesselUid, String? imo}) {
    final normalizedImo = _normalizeValidImo(imo);

    if (normalizedImo != null) {
      return 'imo_$normalizedImo';
    }

    final normalizedVesselUid = vesselUid.trim();

    if (normalizedVesselUid.isEmpty ||
        normalizedVesselUid.contains('/') ||
        normalizedVesselUid.contains(r'\')) {
      throw ArgumentError.value(
        vesselUid,
        'vesselUid',
        'vesselUid must be non-empty and must not contain slashes.',
      );
    }

    return normalizedVesselUid;
  }

  static String thumbnail({required String vesselKey, required int version}) {
    _validateVesselKey(vesselKey);
    _validateVersion(version);

    return 'vessel_photos/$vesselKey/v$version/thumb.jpg';
  }

  static String full({required String vesselKey, required int version}) {
    _validateVesselKey(vesselKey);
    _validateVersion(version);

    return 'vessel_photos/$vesselKey/v$version/full.jpg';
  }

  static bool isValidImo(String? value) {
    return _normalizeValidImo(value) != null;
  }

  static String? _normalizeValidImo(String? value) {
    if (value == null) {
      return null;
    }

    var normalized = value.trim().toUpperCase();

    if (normalized.startsWith('IMO')) {
      normalized = normalized.substring(3).trim();
    }

    normalized = normalized.replaceAll(RegExp(r'\s+'), '');

    if (!RegExp(r'^[0-9]{7}$').hasMatch(normalized)) {
      return null;
    }

    final digits = normalized.codeUnits
        .map((value) => value - 48)
        .toList(growable: false);

    var checksum = 0;

    for (var index = 0; index < 6; index++) {
      checksum += digits[index] * (7 - index);
    }

    final expectedCheckDigit = checksum % 10;

    if (digits[6] != expectedCheckDigit) {
      return null;
    }

    return normalized;
  }

  static void _validateVesselKey(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty ||
        normalized.contains('/') ||
        normalized.contains(r'\')) {
      throw ArgumentError.value(
        value,
        'vesselKey',
        'vesselKey must be non-empty and must not contain slashes.',
      );
    }
  }

  static void _validateVersion(int version) {
    if (version <= 0) {
      throw ArgumentError.value(
        version,
        'version',
        'version must be positive.',
      );
    }
  }
}
