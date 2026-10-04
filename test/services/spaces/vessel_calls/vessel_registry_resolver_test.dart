import 'package:flutter_test/flutter_test.dart';

import 'package:epistola/domain/models/vessel_registry.dart';
import 'package:epistola/services/spaces/vessel_calls/vessel_registry_resolver.dart';
import 'package:epistola/services/spaces/vessel_calls/vessel_registry_seed.dart';

void main() {
  const resolver = VesselRegistryResolver();

  group('VesselRegistryResolver', () {
    test('uses line default for known container line', () {
      final result = resolver.resolve(
        shipName: 'FESCO NOVIK',
        lineName: 'ФИТ',
        vessels: const [],
        lines: vesselLineRegistrySeed,
      );

      expect(result.workType, VesselWorkType.container);
      expect(result.source, VesselClassificationSource.line);
      expect(result.line?.lineId, 'fit');
      expect(result.vessel, isNull);
    });

    test('uses line default for known bulk line', () {
      final result = resolver.resolve(
        shipName: 'KAARI',
        lineName: 'СМАРТ БАЛК',
        vessels: const [],
        lines: vesselLineRegistrySeed,
      );

      expect(result.workType, VesselWorkType.bulk);
      expect(result.source, VesselClassificationSource.line);
      expect(result.line?.lineId, 'smart_bulk');
    });

    test('specific vessel overrides line default', () {
      const vessels = <VesselRegistryEntry>[
        VesselRegistryEntry(
          vesselUid: 'vessel_exception_001',
          name: 'TEST EXCEPTION',
          lineId: 'fit',
          workType: VesselWorkType.other,
          isVerified: true,
        ),
      ];

      final result = resolver.resolve(
        shipName: 'TEST EXCEPTION',
        lineName: 'ФИТ',
        vessels: vessels,
        lines: vesselLineRegistrySeed,
      );

      expect(result.workType, VesselWorkType.other);
      expect(result.source, VesselClassificationSource.vessel);
      expect(result.vessel?.vesselUid, 'vessel_exception_001');
      expect(result.line?.lineId, 'fit');
    });

    test('falls back to line when vessel work type is unknown', () {
      const vessels = <VesselRegistryEntry>[
        VesselRegistryEntry(
          vesselUid: 'vessel_unclassified_001',
          name: 'NEW FESCO SHIP',
          lineId: 'fit',
          workType: VesselWorkType.unknown,
          isVerified: false,
        ),
      ];

      final result = resolver.resolve(
        shipName: 'NEW FESCO SHIP',
        lineName: 'ФИТ',
        vessels: vessels,
        lines: vesselLineRegistrySeed,
      );

      expect(result.workType, VesselWorkType.container);
      expect(result.source, VesselClassificationSource.line);
      expect(result.vessel?.vesselUid, 'vessel_unclassified_001');
    });

    test('returns unknown for unknown vessel and unknown line', () {
      final result = resolver.resolve(
        shipName: 'UNKNOWN SHIP',
        lineName: 'UNKNOWN LINE',
        vessels: const [],
        lines: vesselLineRegistrySeed,
      );

      expect(result.workType, VesselWorkType.unknown);
      expect(result.source, VesselClassificationSource.unknown);
      expect(result.vessel, isNull);
      expect(result.line, isNull);
    });

    test('normalizes spaces and letter case', () {
      final result = resolver.resolve(
        shipName: '  fesco   novik  ',
        lineName: '  фит  ',
        vessels: const [],
        lines: vesselLineRegistrySeed,
      );

      expect(result.workType, VesselWorkType.container);
      expect(result.source, VesselClassificationSource.line);
      expect(result.line?.lineId, 'fit');
    });

    test('prefers vessel with matching line when names collide', () {
      const vessels = <VesselRegistryEntry>[
        VesselRegistryEntry(
          vesselUid: 'sparta_other',
          name: 'SPARTA',
          lineId: 'tbk',
          workType: VesselWorkType.other,
          isVerified: true,
        ),
        VesselRegistryEntry(
          vesselUid: 'sparta_container',
          name: 'SPARTA',
          lineId: 'fit',
          workType: VesselWorkType.container,
          isVerified: true,
        ),
      ];

      const lines = <VesselLineRegistryEntry>[
        VesselLineRegistryEntry(
          lineId: 'fit',
          displayName: 'ФИТ',
          defaultWorkType: VesselWorkType.container,
          isVerified: true,
        ),
      ];

      final result = resolver.resolve(
        shipName: 'SPARTA',
        lineName: 'ФИТ',
        vessels: vessels,
        lines: lines,
      );

      expect(result.vessel?.vesselUid, 'sparta_container');
      expect(result.workType, VesselWorkType.container);
      expect(result.source, VesselClassificationSource.vessel);
    });
  });
}
