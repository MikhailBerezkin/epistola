enum VesselWorkType {
  container('container'),
  bulk('bulk'),
  other('other'),
  unknown('unknown');

  const VesselWorkType(this.storageValue);

  final String storageValue;

  String get displayName {
    return switch (this) {
      VesselWorkType.container => 'Контейнеры',
      VesselWorkType.bulk => 'Балкер',
      VesselWorkType.other => 'Другие суда',
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

enum VesselPhysicalType {
  container('container'),
  bulk('bulk'),
  reefer('reefer'),
  multipurpose('multipurpose'),
  generalCargo('generalCargo'),
  other('other'),
  unknown('unknown');

  const VesselPhysicalType(this.storageValue);

  final String storageValue;

  String get displayName {
    return switch (this) {
      VesselPhysicalType.container => 'Контейнеровоз',
      VesselPhysicalType.bulk => 'Балкер',
      VesselPhysicalType.reefer => 'Рефрижератор',
      VesselPhysicalType.multipurpose => 'Многоцелевое судно',
      VesselPhysicalType.generalCargo => 'Сухогруз',
      VesselPhysicalType.other => 'Другой тип',
      VesselPhysicalType.unknown => 'Не определён',
    };
  }

  static VesselPhysicalType tryParse(Object? value) {
    return switch (value) {
      'container' => VesselPhysicalType.container,
      'bulk' => VesselPhysicalType.bulk,
      'reefer' => VesselPhysicalType.reefer,
      'multipurpose' => VesselPhysicalType.multipurpose,
      'generalCargo' => VesselPhysicalType.generalCargo,
      'other' => VesselPhysicalType.other,
      _ => VesselPhysicalType.unknown,
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
    required this.isVerified,
    VesselWorkType? workType,
    this.defaultWorkType,
    this.allowedWorkTypes = const <VesselWorkType>[],
    this.workTypeOverride,
    this.physicalType = VesselPhysicalType.unknown,
    this.imo,
    this.lengthMeters,
    this.deadweightTons,
    this.teuCapacity,
    this.photoPath,
    this.marineTrafficUrl,
    this.updatedAt,
    this.updatedBy,
  }) : _legacyWorkType = workType;

  /// Внутренний постоянный идентификатор Epistola.
  final String vesselUid;

  final String name;

  /// Ссылка на VesselLineRegistryEntry.lineId.
  final String lineId;

  /// Технический тип самого судна.
  ///
  /// Например:
  /// reefer, multipurpose, container, bulk.
  ///
  /// Это поле не определяет цвет работы на терминале.
  final VesselPhysicalType physicalType;

  /// Рабочая категория судна по умолчанию.
  ///
  /// Например, рефрижератор может иметь:
  /// physicalType = reefer
  /// defaultWorkType = container
  final VesselWorkType? defaultWorkType;

  /// Старое значение workType из schemaVersion 1.
  ///
  /// Используется только как fallback во время миграции.
  final VesselWorkType? _legacyWorkType;

  /// Категории, между которыми разрешено переключать конкретное судно.
  ///
  /// Примеры:
  /// контейнеровоз:
  /// [container]
  ///
  /// рефрижератор:
  /// [container, other]
  ///
  /// multipurpose на линии СМАРТ БАЛК:
  /// [bulk, other]
  final List<VesselWorkType> allowedWorkTypes;

  /// Ручное переопределение рабочей категории.
  ///
  /// null означает использование defaultWorkType.
  final VesselWorkType? workTypeOverride;

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

  /// Рабочая категория без ручного override.
  ///
  /// Поддерживает старое поле workType из schemaVersion 1.
  VesselWorkType get resolvedDefaultWorkType {
    return defaultWorkType ?? _legacyWorkType ?? VesselWorkType.unknown;
  }

  /// Категория, которая фактически используется сейчас
  /// для цвета, фильтрации и отображения судозахода.
  VesselWorkType get effectiveWorkType {
    return workTypeOverride ?? resolvedDefaultWorkType;
  }

  /// Совместимость со старым кодом.
  ///
  /// Старые участки приложения продолжают обращаться к vessel.workType,
  /// но фактически уже получают новую effectiveWorkType.
  VesselWorkType get workType => effectiveWorkType;

  List<VesselWorkType> get effectiveAllowedWorkTypes {
    if (allowedWorkTypes.isNotEmpty) {
      return allowedWorkTypes;
    }

    return <VesselWorkType>[resolvedDefaultWorkType];
  }

  bool get supportsWorkTypeSwitch {
    return effectiveAllowedWorkTypes.toSet().length > 1;
  }

  bool allowsWorkType(VesselWorkType value) {
    return effectiveAllowedWorkTypes.contains(value);
  }
}

String normalizeVesselRegistryText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
}
