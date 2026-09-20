import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/vacation_period.dart';
import 'package:epistola/services/spaces/calendar/vacation_period_firestore_gateway.dart';
import 'package:epistola/services/spaces/calendar/vacation_period_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VacationPeriodService', () {
    test('create uses first free slot', () async {
      String? savedDocumentId;
      Map<String, dynamic>? savedData;

      final gateway = _createGateway(
        existingPeriods: <VacationPeriod>[
          VacationPeriod(
            userId: 'user-1',
            slot: 1,
            startDate: DateTime.utc(2026, 1, 10),
            endDate: DateTime.utc(2026, 1, 20),
          ),
          VacationPeriod(
            userId: 'user-1',
            slot: 3,
            startDate: DateTime.utc(2026, 7, 15),
            endDate: DateTime.utc(2026, 7, 25),
          ),
        ],
        onSave: (documentId, data) {
          savedDocumentId = documentId;
          savedData = data;
        },
      );

      final service = VacationPeriodService(gateway);

      final created = await service.create(
        userId: 'user-1',
        startDate: DateTime.utc(2026, 3, 5),
        endDate: DateTime.utc(2026, 3, 12),
      );

      expect(created.slot, 2);
      expect(savedDocumentId, 'user-1__2');
      expect(savedData?['slot'], 2);
      expect(savedData?['startDay'], 20260305);
      expect(savedData?['endDay'], 20260312);
    });

    test('create throws when all six slots are occupied', () async {
      var saveCalled = false;

      final gateway = _createGateway(
        existingPeriods: List<VacationPeriod>.generate(6, (index) {
          final slot = index + 1;

          return VacationPeriod(
            userId: 'user-1',
            slot: slot,
            startDate: DateTime.utc(2026, slot, 1),
            endDate: DateTime.utc(2026, slot, 5),
          );
        }),
        onSave: (_, _) {
          saveCalled = true;
        },
      );

      final service = VacationPeriodService(gateway);

      await expectLater(
        service.create(
          userId: 'user-1',
          startDate: DateTime.utc(2026, 12, 1),
          endDate: DateTime.utc(2026, 12, 10),
        ),
        throwsStateError,
      );

      expect(saveCalled, isFalse);
    });

    test('update keeps original user and slot', () async {
      String? savedDocumentId;
      Map<String, dynamic>? savedData;

      final gateway = _createGateway(
        existingPeriods: const <VacationPeriod>[],
        onSave: (documentId, data) {
          savedDocumentId = documentId;
          savedData = data;
        },
      );

      final service = VacationPeriodService(gateway);

      final current = VacationPeriod(
        userId: 'user-1',
        slot: 4,
        startDate: DateTime.utc(2026, 5, 1),
        endDate: DateTime.utc(2026, 5, 10),
      );

      final updated = await service.update(
        currentPeriod: current,
        startDate: DateTime.utc(2026, 5, 20),
        endDate: DateTime.utc(2026, 5, 30),
      );

      expect(updated.userId, 'user-1');
      expect(updated.slot, 4);
      expect(savedDocumentId, 'user-1__4');
      expect(savedData?['startDay'], 20260520);
      expect(savedData?['endDay'], 20260530);
    });

    test('delete keeps original user and slot', () async {
      String? deletedDocumentId;

      final gateway = _createGateway(
        existingPeriods: const <VacationPeriod>[],
        onDelete: (documentId) {
          deletedDocumentId = documentId;
        },
      );

      final service = VacationPeriodService(gateway);

      final period = VacationPeriod(
        userId: 'user-1',
        slot: 5,
        startDate: DateTime.utc(2026, 9, 18),
        endDate: DateTime.utc(2026, 10, 2),
      );

      await service.delete(period: period);

      expect(deletedDocumentId, 'user-1__5');
    });

    test('update rejects reversed dates', () async {
      var saveCalled = false;

      final gateway = _createGateway(
        existingPeriods: const <VacationPeriod>[],
        onSave: (_, _) {
          saveCalled = true;
        },
      );

      final service = VacationPeriodService(gateway);

      final current = VacationPeriod(
        userId: 'user-1',
        slot: 2,
        startDate: DateTime.utc(2026, 9, 18),
        endDate: DateTime.utc(2026, 10, 2),
      );

      await expectLater(
        service.update(
          currentPeriod: current,
          startDate: DateTime.utc(2026, 10, 10),
          endDate: DateTime.utc(2026, 10, 1),
        ),
        throwsArgumentError,
      );

      expect(saveCalled, isFalse);
    });
  });
}

typedef _SaveCallback =
    void Function(String documentId, Map<String, dynamic> data);

typedef _DeleteCallback = void Function(String documentId);

VacationPeriodFirestoreGateway _createGateway({
  required List<VacationPeriod> existingPeriods,
  _SaveCallback? onSave,
  _DeleteCallback? onDelete,
}) {
  return VacationPeriodFirestoreGateway(
    documentsLoader: ({required String userId}) async {
      return existingPeriods
          .where((period) => period.userId == userId)
          .map(
            (period) => (
              id: period.documentId,
              data: <String, dynamic>{
                'schemaVersion': 1,
                'userId': period.userId,
                'slot': period.slot,
                'startDay':
                    period.startDate.year * 10000 +
                    period.startDate.month * 100 +
                    period.startDate.day,
                'endDay':
                    period.endDate.year * 10000 +
                    period.endDate.month * 100 +
                    period.endDate.day,
                'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 19, 12)),
              },
            ),
          )
          .toList(growable: false);
    },
    documentSaver:
        ({
          required String documentId,
          required Map<String, dynamic> data,
        }) async {
          onSave?.call(documentId, data);
        },
    documentDeleter: ({required String documentId}) async {
      onDelete?.call(documentId);
    },
  );
}
