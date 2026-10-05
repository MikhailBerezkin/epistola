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

    final legacyWorkType = VesselWorkType.tryParse(data['workType']);

    final defaultWorkType =
        _readNullableWorkType(data['defaultWorkType']) ?? legacyWorkType;

    return VesselRegistryEntry(
      vesselUid: normalizedVesselUid,
      name: name,
      lineId: lineId,
      workType: legacyWorkType,
      defaultWorkType: defaultWorkType,
      allowedWorkTypes: _readWorkTypeList(data['allowedWorkTypes']),
      workTypeOverride: _readNullableWorkType(data['workTypeOverride']),
      physicalType: VesselPhysicalType.tryParse(data['physicalType']),
      isVerified: data['isVerified'] == true,
      imo: _readNullableString(data['imo']),
      lengthMeters: _readNullableDouble(data['lengthMeters']),
      deadweightTons: _readNullableInt(data['deadweightTons']),
      teuCapacity: _readNullableInt(data['teuCapacity']),

      // Старое поле оставляем для совместимости.
      photoPath: _readNullableString(data['photoPath']),

      // Новая схема фотографий судна.
      photoThumbPath: _readNullableString(data['photoThumbPath']),
      photoFullPath: _readNullableString(data['photoFullPath']),
      photoVersion: _readPositiveNullableInt(data['photoVersion']),

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

    final defaultWorkType = vessel.resolvedDefaultWorkType;
    final allowedWorkTypes = vessel.effectiveAllowedWorkTypes;

    final uniqueAllowedWorkTypes = <VesselWorkType>{
      ...allowedWorkTypes,
    }.toList(growable: false);

    if (!uniqueAllowedWorkTypes.contains(defaultWorkType)) {
      throw ArgumentError.value(
        allowedWorkTypes,
        'allowedWorkTypes',
        'allowedWorkTypes must contain defaultWorkType.',
      );
    }

    final workTypeOverride = vessel.workTypeOverride;

    if (workTypeOverride != null &&
        !uniqueAllowedWorkTypes.contains(workTypeOverride)) {
      throw ArgumentError.value(
        workTypeOverride,
        'workTypeOverride',
        'workTypeOverride must be included in allowedWorkTypes.',
      );
    }

    final photoVersion = vessel.photoVersion;

    if (photoVersion != null && photoVersion <= 0) {
      throw ArgumentError.value(
        photoVersion,
        'photoVersion',
        'photoVersion must be positive.',
      );
    }

    return <String, dynamic>{
      'schemaVersion': 2,
      'name': name,
      'normalizedName': normalizeVesselRegistryText(name),
      'lineId': vessel.lineId.trim(),

      // Схема классификации.
      'physicalType': vessel.physicalType.storageValue,
      'defaultWorkType': defaultWorkType.storageValue,
      'allowedWorkTypes': uniqueAllowedWorkTypes
          .map((value) => value.storageValue)
          .toList(growable: false),
      'workTypeOverride': workTypeOverride?.storageValue,

      // Старые версии клиента продолжают видеть фактическую категорию.
      'workType': vessel.effectiveWorkType.storageValue,

      'isVerified': vessel.isVerified,
      'imo': _normalizeNullableString(vessel.imo),
      'lengthMeters': vessel.lengthMeters,
      'deadweightTons': vessel.deadweightTons,
      'teuCapacity': vessel.teuCapacity,

      // Legacy.
      'photoPath': _normalizeNullableString(vessel.photoPath),

      // Новая двухуровневая фотография.
      'photoThumbPath': _normalizeNullableString(vessel.photoThumbPath),
      'photoFullPath': _normalizeNullableString(vessel.photoFullPath),
      'photoVersion': photoVersion,

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

  static VesselWorkType? _readNullableWorkType(Object? value) {
    return switch (value) {
      'container' => VesselWorkType.container,
      'bulk' => VesselWorkType.bulk,
      'special' => VesselWorkType.special,
      'other' => VesselWorkType.other,
      'unknown' => VesselWorkType.unknown,
      _ => null,
    };
  }

  static List<VesselWorkType> _readWorkTypeList(Object? value) {
    if (value is! Iterable) {
      return const <VesselWorkType>[];
    }

    final result = <VesselWorkType>[];

    for (final item in value) {
      final workType = _readNullableWorkType(item);

      if (workType == null || result.contains(workType)) {
        continue;
      }

      result.add(workType);
    }

    return List<VesselWorkType>.unmodifiable(result);
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

  static int? _readPositiveNullableInt(Object? value) {
    if (value is! num) {
      return null;
    }

    final result = value.toInt();

    return result > 0 ? result : null;
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
