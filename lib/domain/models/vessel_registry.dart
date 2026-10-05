enum VesselWorkType {
  container('container'),
  bulk('bulk'),
  special('special'),
  other('other'),
  unknown('unknown');

  const VesselWorkType(this.storageValue);

  final String storageValue;

  String get displayName {
    return switch (this) {
      VesselWorkType.container => 'Контейнеры',
      VesselWorkType.bulk => 'Балкер / сыпучие',
      VesselWorkType.special => 'Не обрабатывается',
      VesselWorkType.other => 'Другие грузы',
      VesselWorkType.unknown => 'Не определён',
    };
  }

  static VesselWorkType tryParse(Object? value) {
    return switch (value) {
      'container' => VesselWorkType.container,
      'bulk' => VesselWorkType.bulk,
      'special' => VesselWorkType.special,
      'other' => VesselWorkType.other,
      _ => VesselWorkType.unknown,
    };
  }
}

enum VesselPhysicalType {
  container('container'),
  bulk('bulk'),
  generalCargo('generalCargo'),
  tanker('tanker'),
  icebreaker('icebreaker'),
  tug('tug'),
  reefer('reefer'),
  multipurpose('multipurpose'),
  roRo('roRo'),
  ferry('ferry'),
  other('other'),
  unknown('unknown');

  const VesselPhysicalType(this.storageValue);

  final String storageValue;

  String get displayName {
    return switch (this) {
      VesselPhysicalType.container => 'Контейнеровоз',
      VesselPhysicalType.bulk => 'Балкер',
      VesselPhysicalType.generalCargo => 'Сухогруз',
      VesselPhysicalType.tanker => 'Танкер',
      VesselPhysicalType.icebreaker => 'Ледокол',
      VesselPhysicalType.tug => 'Буксир',
      VesselPhysicalType.reefer => 'Рефрижератор',
      VesselPhysicalType.multipurpose => 'Многоцелевое судно',
      VesselPhysicalType.roRo => 'Ро-ро',
      VesselPhysicalType.ferry => 'Паром',
      VesselPhysicalType.other => 'Другой тип',
      VesselPhysicalType.unknown => 'Не определён',
    };
  }

  static VesselPhysicalType tryParse(Object? value) {
    return switch (value) {
      'container' => VesselPhysicalType.container,
      'bulk' => VesselPhysicalType.bulk,
      'generalCargo' => VesselPhysicalType.generalCargo,
      'tanker' => VesselPhysicalType.tanker,
      'icebreaker' => VesselPhysicalType.icebreaker,
      'tug' => VesselPhysicalType.tug,
      'reefer' => VesselPhysicalType.reefer,
      'multipurpose' => VesselPhysicalType.multipurpose,
      'roRo' => VesselPhysicalType.roRo,
      'ferry' => VesselPhysicalType.ferry,
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

  /// Каноническое имя судна в реестре.
  ///
  /// Имя, пришедшее в конкретном судозаходе от ПКТ,
  /// должно храниться отдельно в данных судозахода.
  final String name;

  /// Ссылка на VesselLineRegistryEntry.lineId.
  final String lineId;

  /// Физический тип самого судна.
  ///
  /// Это справочная характеристика судна и она не определяет
  /// цвет полосы судозахода.
  final VesselPhysicalType physicalType;

  /// Рабочая категория по умолчанию.
  ///
  /// Используется автоматикой, если для конкретного захода
  /// нет ручного выбора.
  final VesselWorkType? defaultWorkType;

  /// Старое значение workType из schemaVersion 1.
  ///
  /// Используется только как fallback во время миграции.
  final VesselWorkType? _legacyWorkType;

  /// Историческое поле schemaVersion 2.
  ///
  /// Оно остаётся в модели для обратной совместимости,
  /// но универсальный UI больше не обязан ограничивать выбор
  /// этим списком.
  final List<VesselWorkType> allowedWorkTypes;

  /// Ручное переопределение рабочего статуса.
  ///
  /// Именно это значение используется для текущей ручной
  /// классификации:
  /// container / bulk / special / other.
  ///
  /// null означает использование defaultWorkType.
  final VesselWorkType? workTypeOverride;

  /// true означает, что постоянные данные карточки
  /// были проверены человеком.
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

  VesselWorkType get resolvedDefaultWorkType {
    return defaultWorkType ?? _legacyWorkType ?? VesselWorkType.unknown;
  }

  VesselWorkType get effectiveWorkType {
    return workTypeOverride ?? resolvedDefaultWorkType;
  }

  /// Совместимость со старым кодом.
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
