import 'package:flutter_test/flutter_test.dart';

import 'package:epistola/domain/models/vessel_registry.dart';
import 'package:epistola/services/spaces/vessel_calls/vessel_registry_firestore_gateway.dart';

void main() {
  group('VesselRegistryFirestoreGateway', () {
    test('loads valid lines and skips invalid ones', () async {
      final gateway = VesselRegistryFirestoreGateway(
        lineReader: () async {
          return <VesselRegistryDocument>[
            const VesselRegistryDocument(
              id: 'fit',
              data: <String, dynamic>{
                'displayName': 'ФИТ',
                'defaultWorkType': 'container',
                'isVerified': true,
              },
            ),
            const VesselRegistryDocument(
              id: 'broken',
              data: <String, dynamic>{'displayName': ''},
            ),
          ];
        },
        vesselReader: () async => const <VesselRegistryDocument>[],
        lineWriter:
            ({
              required String documentId,
              required Map<String, dynamic> data,
            }) async {},
        vesselWriter:
            ({
              required String documentId,
              required Map<String, dynamic> data,
            }) async {},
      );

      final lines = await gateway.loadLines();

      expect(lines, hasLength(1));
      expect(lines.single.lineId, 'fit');
      expect(lines.single.defaultWorkType, VesselWorkType.container);
    });

    test('loads valid vessels and skips invalid ones', () async {
      final gateway = VesselRegistryFirestoreGateway(
        lineReader: () async => const <VesselRegistryDocument>[],
        vesselReader: () async {
          return <VesselRegistryDocument>[
            const VesselRegistryDocument(
              id: 'vessel_001',
              data: <String, dynamic>{
                'name': 'FESCO NOVIK',
                'lineId': 'fit',
                'workType': 'container',
                'isVerified': true,
              },
            ),
            const VesselRegistryDocument(
              id: 'broken',
              data: <String, dynamic>{'name': '', 'lineId': 'fit'},
            ),
          ];
        },
        lineWriter:
            ({
              required String documentId,
              required Map<String, dynamic> data,
            }) async {},
        vesselWriter:
            ({
              required String documentId,
              required Map<String, dynamic> data,
            }) async {},
      );

      final vessels = await gateway.loadVessels();

      expect(vessels, hasLength(1));
      expect(vessels.single.vesselUid, 'vessel_001');
      expect(vessels.single.name, 'FESCO NOVIK');
    });

    test('saves line with expected document id and data', () async {
      String? capturedId;
      Map<String, dynamic>? capturedData;

      final gateway = VesselRegistryFirestoreGateway(
        lineReader: () async => const <VesselRegistryDocument>[],
        vesselReader: () async => const <VesselRegistryDocument>[],
        lineWriter:
            ({
              required String documentId,
              required Map<String, dynamic> data,
            }) async {
              capturedId = documentId;
              capturedData = data;
            },
        vesselWriter:
            ({
              required String documentId,
              required Map<String, dynamic> data,
            }) async {},
      );

      await gateway.saveLine(
        line: const VesselLineRegistryEntry(
          lineId: 'fit',
          displayName: 'ФИТ',
          defaultWorkType: VesselWorkType.container,
          isVerified: true,
        ),
        updatedBy: 'owner_1',
      );

      expect(capturedId, 'fit');
      expect(capturedData?['displayName'], 'ФИТ');
      expect(capturedData?['defaultWorkType'], 'container');
      expect(capturedData?['updatedBy'], 'owner_1');
    });

    test('saves vessel with expected document id and data', () async {
      String? capturedId;
      Map<String, dynamic>? capturedData;

      final gateway = VesselRegistryFirestoreGateway(
        lineReader: () async => const <VesselRegistryDocument>[],
        vesselReader: () async => const <VesselRegistryDocument>[],
        lineWriter:
            ({
              required String documentId,
              required Map<String, dynamic> data,
            }) async {},
        vesselWriter:
            ({
              required String documentId,
              required Map<String, dynamic> data,
            }) async {
              capturedId = documentId;
              capturedData = data;
            },
      );

      await gateway.saveVessel(
        vessel: const VesselRegistryEntry(
          vesselUid: 'vessel_001',
          name: 'FESCO NOVIK',
          lineId: 'fit',
          workType: VesselWorkType.container,
          isVerified: true,
          imo: '1234567',
        ),
        updatedBy: 'brigadier_1',
      );

      expect(capturedId, 'vessel_001');
      expect(capturedData?['name'], 'FESCO NOVIK');
      expect(capturedData?['lineId'], 'fit');
      expect(capturedData?['workType'], 'container');
      expect(capturedData?['imo'], '1234567');
      expect(capturedData?['updatedBy'], 'brigadier_1');
    });
  });
}
