import '../../../domain/models/vessel_registry.dart';

const vesselLineRegistrySeed = <VesselLineRegistryEntry>[
  VesselLineRegistryEntry(
    lineId: 'fit',
    displayName: 'ФИТ',
    defaultWorkType: VesselWorkType.container,
    isVerified: true,
  ),
  VesselLineRegistryEntry(
    lineId: 'smart_bulk',
    displayName: 'СМАРТ БАЛК',
    defaultWorkType: VesselWorkType.bulk,
    isVerified: true,
  ),
  VesselLineRegistryEntry(
    lineId: 'sai_fu',
    displayName: 'САЙ ФУ',
    defaultWorkType: VesselWorkType.container,
    isVerified: true,
  ),
  VesselLineRegistryEntry(
    lineId: 'novik_logistic',
    displayName: 'НОВИК ЛОГИСТИК',
    defaultWorkType: VesselWorkType.container,
    isVerified: true,
  ),
  VesselLineRegistryEntry(
    lineId: 'mirtrans',
    displayName: 'МИРТРАНС',
    defaultWorkType: VesselWorkType.container,
    isVerified: true,
  ),
];
