import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/vessel_registry.dart';

final class VesselRegistryFirestoreMapper {
  const VesselRegistryFirestoreMapper._();

  static VesselLineRegistryEntry? lineFromMap({
    required String lineId,
    required Map<String, dynamic> data,
  }) {
    final normalizedLineId = lineId.trim();
    final displayName = _readString(data['displayName']);

    if (normalizedLineId.isEmpty || displayName.isEmpty) {
      return null;
    }

    return VesselLineRegistryEntry(
      lineId: normalizedLineId,
      displayName: displayName,
      defaultWorkType: VesselWorkType.tryParse(data['defaultWorkType']),
      isVerified: data['isVerified'] == true,
      updatedAt: _readDateTime(data['updatedAt']),
      updatedBy: _readNullableString(data['updatedBy']),
    );
  }

  static Map<String, dynamic> lineToMap({
    required VesselLineRegistryEntry line,
    required String updatedBy,
  }) {
    _validateDocumentId(line.lineId, fieldName: 'lineId');
    _validateUpdatedBy(updatedBy);

    final displayName = line.displayName.trim();

    if (displayName.isEmpty) {
      throw ArgumentError.value(
        line.displayName,
        'displayName',
        'Line display name must not be empty.',
      );
    }

    return <String, dynamic>{
      'schemaVersion': 1,
      'displayName': displayName,
      'normalizedName': normalizeVesselRegistryText(displayName),
      'defaultWorkType': line.defaultWorkType.storageValue,
      'isVerified': line.isVerified,
      'updatedBy': updatedBy.trim(),
    };
  }

  static VesselRegistryEntry? vesselFromMap({
    required String vesselUid,
    required Map<String, dynamic> data,
  }) {
    final normalizedVesselUid = vesselUid.trim();
    final name = _readString(data['name']);
    final lineId = _readString(data['lineId']);

    if (normalizedVesselUid.isEmpty || name.isEmpty || lineId.isEmpty) {
      return null;
    }

    return VesselRegistryEntry(
      vesselUid: normalizedVesselUid,
      name: name,
      lineId: lineId,
      workType: VesselWorkType.tryParse(data['workType']),
      isVerified: data['isVerified'] == true,
      imo: _readNullableString(data['imo']),
      lengthMeters: _readNullableDouble(data['lengthMeters']),
      deadweightTons: _readNullableInt(data['deadweightTons']),
      teuCapacity: _readNullableInt(data['teuCapacity']),
      photoPath: _readNullableString(data['photoPath']),
      marineTrafficUrl: _readNullableString(data['marineTrafficUrl']),
      updatedAt: _readDateTime(data['updatedAt']),
      updatedBy: _readNullableString(data['updatedBy']),
    );
  }

  static Map<String, dynamic> vesselToMap({
    required VesselRegistryEntry vessel,
    required String updatedBy,
  }) {
    _validateDocumentId(vessel.vesselUid, fieldName: 'vesselUid');
    _validateDocumentId(vessel.lineId, fieldName: 'lineId');
    _validateUpdatedBy(updatedBy);

    final name = vessel.name.trim();

    if (name.isEmpty) {
      throw ArgumentError.value(
        vessel.name,
        'name',
        'Vessel name must not be empty.',
      );
    }

    return <String, dynamic>{
      'schemaVersion': 1,
      'name': name,
      'normalizedName': normalizeVesselRegistryText(name),
      'lineId': vessel.lineId.trim(),
      'workType': vessel.workType.storageValue,
      'isVerified': vessel.isVerified,
      'imo': _normalizeNullableString(vessel.imo),
      'lengthMeters': vessel.lengthMeters,
      'deadweightTons': vessel.deadweightTons,
      'teuCapacity': vessel.teuCapacity,
      'photoPath': _normalizeNullableString(vessel.photoPath),
      'marineTrafficUrl': _normalizeNullableString(vessel.marineTrafficUrl),
      'updatedBy': updatedBy.trim(),
    };
  }

  static String _readString(Object? value) {
    return value is String ? value.trim() : '';
  }

  static String? _readNullableString(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static double? _readNullableDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  static int? _readNullableInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return null;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static String? _normalizeNullableString(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static void _validateDocumentId(String value, {required String fieldName}) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(
        value,
        fieldName,
        '$fieldName must be non-empty and must not contain slashes.',
      );
    }
  }

  static void _validateUpdatedBy(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(
        value,
        'updatedBy',
        'updatedBy must be a valid user ID.',
      );
    }
  }
}
