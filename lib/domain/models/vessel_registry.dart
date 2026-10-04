enum VesselWorkType {
  container('container'),
  bulk('bulk'),
  other('other'),
  unknown('unknown');

  const VesselWorkType(this.storageValue);

  final String storageValue;

  String get displayName {
    return switch (this) {
      VesselWorkType.container => 'Контейнеровоз',
      VesselWorkType.bulk => 'Балкер',
      VesselWorkType.other => 'Другое',
      VesselWorkType.unknown => 'Не определён',
    };
  }

  static VesselWorkType tryParse(Object? value) {
    return switch (value) {
      'container' => VesselWorkType.container,
      'bulk' => VesselWorkType.bulk,
      'other' => VesselWorkType.other,
      _ => VesselWorkType.unknown,
    };
  }
}

final class VesselLineRegistryEntry {
  const VesselLineRegistryEntry({
    required this.lineId,
    required this.displayName,
    required this.defaultWorkType,
    required this.isVerified,
    this.updatedAt,
    this.updatedBy,
  });

  final String lineId;
  final String displayName;
  final VesselWorkType defaultWorkType;
  final bool isVerified;

  final DateTime? updatedAt;
  final String? updatedBy;

  String get normalizedName => normalizeVesselRegistryText(displayName);
}

final class VesselRegistryEntry {
  const VesselRegistryEntry({
    required this.vesselUid,
    required this.name,
    required this.lineId,
    required this.workType,
    required this.isVerified,
    this.imo,
    this.lengthMeters,
    this.deadweightTons,
    this.teuCapacity,
    this.photoPath,
    this.marineTrafficUrl,
    this.updatedAt,
    this.updatedBy,
  });

  /// Внутренний постоянный идентификатор Epistola.
  final String vesselUid;

  final String name;

  /// Ссылка на VesselLineRegistryEntry.lineId.
  final String lineId;

  /// Тип конкретного судна имеет приоритет над defaultWorkType линии.
  final VesselWorkType workType;

  final bool isVerified;

  final String? imo;

  final double? lengthMeters;

  final int? deadweightTons;

  final int? teuCapacity;

  /// Firebase Storage path.
  final String? photoPath;

  final String? marineTrafficUrl;

  final DateTime? updatedAt;
  final String? updatedBy;

  String get normalizedName => normalizeVesselRegistryText(name);
}

String normalizeVesselRegistryText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
}
