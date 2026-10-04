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

    test('maps vessel to Firestore data', () {
      const vessel = VesselRegistryEntry(
        vesselUid: 'vessel_001',
        name: 'FESCO NOVIK',
        lineId: 'fit',
        workType: VesselWorkType.container,
        isVerified: true,
        imo: '1234567',
        lengthMeters: 170.5,
        deadweightTons: 23500,
        teuCapacity: 1730,
        photoPath: 'vessel_avatars/vessel_001/v1/full.jpg',
        marineTrafficUrl: 'https://example.com/vessel',
      );

      final data = VesselRegistryFirestoreMapper.vesselToMap(
        vessel: vessel,
        updatedBy: 'owner_1',
      );

      expect(data['schemaVersion'], 1);
      expect(data['name'], 'FESCO NOVIK');
      expect(data['normalizedName'], 'FESCO NOVIK');
      expect(data['lineId'], 'fit');
      expect(data['workType'], 'container');
      expect(data['isVerified'], true);
      expect(data['imo'], '1234567');
      expect(data['lengthMeters'], 170.5);
      expect(data['deadweightTons'], 23500);
      expect(data['teuCapacity'], 1730);
      expect(data['photoPath'], 'vessel_avatars/vessel_001/v1/full.jpg');
      expect(data['marineTrafficUrl'], 'https://example.com/vessel');
      expect(data['updatedBy'], 'owner_1');
    });

    test('maps Firestore data to vessel', () {
      final vessel = VesselRegistryFirestoreMapper.vesselFromMap(
        vesselUid: 'vessel_002',
        data: <String, dynamic>{
          'name': 'KAARI',
          'lineId': 'smart_bulk',
          'workType': 'bulk',
          'isVerified': true,
          'imo': '7654321',
          'lengthMeters': 180,
          'deadweightTons': 32000,
          'teuCapacity': null,
          'photoPath': null,
          'marineTrafficUrl': null,
          'updatedBy': 'brigadier_2',
        },
      );

      expect(vessel, isNotNull);
      expect(vessel!.vesselUid, 'vessel_002');
      expect(vessel.name, 'KAARI');
      expect(vessel.lineId, 'smart_bulk');
      expect(vessel.workType, VesselWorkType.bulk);
      expect(vessel.isVerified, true);
      expect(vessel.imo, '7654321');
      expect(vessel.lengthMeters, 180);
      expect(vessel.deadweightTons, 32000);
      expect(vessel.teuCapacity, isNull);
      expect(vessel.photoPath, isNull);
      expect(vessel.marineTrafficUrl, isNull);
      expect(vessel.updatedBy, 'brigadier_2');
    });

    test('unknown work type falls back to unknown', () {
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
  });
}
