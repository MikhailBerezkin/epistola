import 'package:flutter_test/flutter_test.dart';

import 'package:epistola/domain/models/vessel_registry.dart';
import 'package:epistola/services/spaces/vessel_calls/vessel_registry_firestore_mapper.dart';

void main() {
  group('VesselRegistryFirestoreMapper', () {
    test('maps line to Firestore data', () {
      const line = VesselLineRegistryEntry(
        lineId: 'fit',
        displayName: 'ФИТ',
        defaultWorkType: VesselWorkType.container,
        isVerified: true,
      );

      final data = VesselRegistryFirestoreMapper.lineToMap(
        line: line,
        updatedBy: 'owner_1',
      );

      expect(data['schemaVersion'], 1);
      expect(data['displayName'], 'ФИТ');
      expect(data['normalizedName'], 'ФИТ');
      expect(data['defaultWorkType'], 'container');
      expect(data['isVerified'], true);
      expect(data['updatedBy'], 'owner_1');
    });

    test('maps Firestore data to line', () {
      final line = VesselRegistryFirestoreMapper.lineFromMap(
        lineId: 'smart_bulk',
        data: <String, dynamic>{
          'displayName': 'СМАРТ БАЛК',
          'defaultWorkType': 'bulk',
          'isVerified': true,
          'updatedBy': 'brigadier_1',
        },
      );

      expect(line, isNotNull);
      expect(line!.lineId, 'smart_bulk');
      expect(line.displayName, 'СМАРТ БАЛК');
      expect(line.defaultWorkType, VesselWorkType.bulk);
      expect(line.isVerified, true);
      expect(line.updatedBy, 'brigadier_1');
    });

    test('rejects line with empty display name', () {
      final line = VesselRegistryFirestoreMapper.lineFromMap(
        lineId: 'fit',
        data: <String, dynamic>{
          'displayName': '   ',
          'defaultWorkType': 'container',
          'isVerified': true,
        },
      );

      expect(line, isNull);
    });

    test('maps schema version 2 vessel to Firestore data', () {
      const vessel = VesselRegistryEntry(
        vesselUid: 'imo_9296999',
        name: 'FESCO NAVARIN',
        lineId: 'fit',
        physicalType: VesselPhysicalType.container,
        defaultWorkType: VesselWorkType.container,
        allowedWorkTypes: <VesselWorkType>[VesselWorkType.container],
        isVerified: true,
        imo: '9296999',
        lengthMeters: 133,
        deadweightTons: 8505,
        teuCapacity: 707,
        photoPath: 'vessel_avatars/imo_9296999/v1/full.jpg',
        marineTrafficUrl: 'https://example.com/vessel',
      );

      final data = VesselRegistryFirestoreMapper.vesselToMap(
        vessel: vessel,
        updatedBy: 'owner_1',
      );

      expect(data['schemaVersion'], 2);
      expect(data['name'], 'FESCO NAVARIN');
      expect(data['normalizedName'], 'FESCO NAVARIN');
      expect(data['lineId'], 'fit');

      expect(data['physicalType'], 'container');
      expect(data['defaultWorkType'], 'container');
      expect(data['allowedWorkTypes'], <String>['container']);
      expect(data['workTypeOverride'], isNull);

      // Поле schemaVersion 1 пока сохраняется для совместимости.
      expect(data['workType'], 'container');

      expect(data['isVerified'], true);
      expect(data['imo'], '9296999');
      expect(data['lengthMeters'], 133);
      expect(data['deadweightTons'], 8505);
      expect(data['teuCapacity'], 707);
      expect(data['photoPath'], 'vessel_avatars/imo_9296999/v1/full.jpg');
      expect(data['marineTrafficUrl'], 'https://example.com/vessel');
      expect(data['updatedBy'], 'owner_1');
    });

    test('maps schema version 2 Firestore data to vessel', () {
      final vessel = VesselRegistryFirestoreMapper.vesselFromMap(
        vesselUid: 'imo_9125695',
        data: <String, dynamic>{
          'schemaVersion': 2,
          'name': 'KERLI',
          'lineId': 'smart_bulk',
          'physicalType': 'multipurpose',
          'defaultWorkType': 'bulk',
          'allowedWorkTypes': <String>['bulk', 'other'],
          'workTypeOverride': 'other',
          'workType': 'other',
          'isVerified': true,
          'imo': '9125695',
          'lengthMeters': 89.77,
          'deadweightTons': 4635,
          'teuCapacity': 221,
          'photoPath': null,
          'marineTrafficUrl': null,
          'updatedBy': 'brigadier_2',
        },
      );

      expect(vessel, isNotNull);

      expect(vessel!.vesselUid, 'imo_9125695');
      expect(vessel.name, 'KERLI');
      expect(vessel.lineId, 'smart_bulk');

      expect(vessel.physicalType, VesselPhysicalType.multipurpose);

      expect(vessel.resolvedDefaultWorkType, VesselWorkType.bulk);

      expect(vessel.allowedWorkTypes, <VesselWorkType>[
        VesselWorkType.bulk,
        VesselWorkType.other,
      ]);

      expect(vessel.workTypeOverride, VesselWorkType.other);

      expect(vessel.effectiveWorkType, VesselWorkType.other);

      // Старый вызов тоже должен получить effectiveWorkType.
      expect(vessel.workType, VesselWorkType.other);

      expect(vessel.supportsWorkTypeSwitch, true);
      expect(vessel.isVerified, true);
      expect(vessel.imo, '9125695');
      expect(vessel.lengthMeters, 89.77);
      expect(vessel.deadweightTons, 4635);
      expect(vessel.teuCapacity, 221);
    });

    test('reads old schema version 1 vessel', () {
      final vessel = VesselRegistryFirestoreMapper.vesselFromMap(
        vesselUid: 'legacy_001',
        data: <String, dynamic>{
          'schemaVersion': 1,
          'name': 'LEGACY SHIP',
          'lineId': 'fit',
          'workType': 'container',
          'isVerified': true,
          'imo': '1234567',
        },
      );

      expect(vessel, isNotNull);

      expect(vessel!.physicalType, VesselPhysicalType.unknown);

      expect(vessel.resolvedDefaultWorkType, VesselWorkType.container);

      expect(vessel.effectiveWorkType, VesselWorkType.container);

      expect(vessel.effectiveAllowedWorkTypes, <VesselWorkType>[
        VesselWorkType.container,
      ]);

      expect(vessel.workTypeOverride, isNull);
      expect(vessel.supportsWorkTypeSwitch, false);
    });

    test('reefer can default to containers and allow other work', () {
      final vessel = VesselRegistryFirestoreMapper.vesselFromMap(
        vesselUid: 'imo_9836880',
        data: <String, dynamic>{
          'schemaVersion': 2,
          'name': 'COOL EXPLORER',
          'lineId': 'baltic_ship',
          'physicalType': 'reefer',
          'defaultWorkType': 'container',
          'allowedWorkTypes': <String>['container', 'other'],
          'workTypeOverride': null,
          'workType': 'container',
          'isVerified': true,
        },
      );

      expect(vessel, isNotNull);

      expect(vessel!.physicalType, VesselPhysicalType.reefer);

      expect(vessel.resolvedDefaultWorkType, VesselWorkType.container);

      expect(vessel.effectiveWorkType, VesselWorkType.container);

      expect(vessel.supportsWorkTypeSwitch, true);
      expect(vessel.allowsWorkType(VesselWorkType.other), true);
    });

    test('unknown legacy work type falls back to unknown', () {
      final vessel = VesselRegistryFirestoreMapper.vesselFromMap(
        vesselUid: 'vessel_003',
        data: <String, dynamic>{
          'name': 'UNKNOWN SHIP',
          'lineId': 'unknown_line',
          'workType': 'something_new',
          'isVerified': false,
        },
      );

      expect(vessel, isNotNull);
      expect(vessel!.workType, VesselWorkType.unknown);
    });

    test('rejects vessel without line id', () {
      final vessel = VesselRegistryFirestoreMapper.vesselFromMap(
        vesselUid: 'vessel_004',
        data: <String, dynamic>{
          'name': 'TEST SHIP',
          'lineId': '',
          'workType': 'container',
          'isVerified': true,
        },
      );

      expect(vessel, isNull);
    });

    test('rejects override outside allowed work types', () {
      const vessel = VesselRegistryEntry(
        vesselUid: 'imo_test',
        name: 'TEST',
        lineId: 'fit',
        defaultWorkType: VesselWorkType.container,
        allowedWorkTypes: <VesselWorkType>[
          VesselWorkType.container,
          VesselWorkType.other,
        ],
        workTypeOverride: VesselWorkType.bulk,
        isVerified: false,
      );

      expect(
        () => VesselRegistryFirestoreMapper.vesselToMap(
          vessel: vessel,
          updatedBy: 'owner_1',
        ),
        throwsArgumentError,
      );
    });
  });
}
