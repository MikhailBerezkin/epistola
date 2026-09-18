import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/vacation_period.dart';
import 'package:epistola/services/spaces/calendar/vacation_period_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VacationPeriodFirestoreGateway', () {
    test('loads normalized user periods sorted by slot', () async {
      String? loadedUserId;

      final gateway = VacationPeriodFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          loadedUserId = userId;

          return <VacationPeriodDocument>[
            (
              id: 'user-1__3',
              data: _vacationPeriodData(
                userId: 'user-1',
                slot: 3,
                startDay: 20261201,
                endDay: 20261214,
              ),
            ),
            (
              id: 'user-1__1',
              data: _vacationPeriodData(
                userId: 'user-1',
                slot: 1,
                startDay: 20261005,
                endDay: 20261018,
              ),
            ),
          ];
        },
        documentSaver: _noOpSaver,
        documentDeleter: _noOpDeleter,
      );

      final periods = await gateway.loadForUser(userId: ' user-1 ');

      expect(loadedUserId, 'user-1');
      expect(periods.map((period) => period.slot), <int>[1, 3]);
    });

    test(
      'rejects period whose document id does not match user and slot',
      () async {
        final gateway = VacationPeriodFirestoreGateway(
          documentsLoader: ({required String userId}) async {
            return <VacationPeriodDocument>[
              (
                id: 'wrong-id',
                data: _vacationPeriodData(
                  userId: userId,
                  slot: 1,
                  startDay: 20261005,
                  endDay: 20261018,
                ),
              ),
            ];
          },
          documentSaver: _noOpSaver,
          documentDeleter: _noOpDeleter,
        );

        await expectLater(
          gateway.loadForUser(userId: 'user-1'),
          throwsStateError,
        );
      },
    );

    test('rejects period belonging to another user', () async {
      final gateway = VacationPeriodFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          return <VacationPeriodDocument>[
            (
              id: 'user-2__1',
              data: _vacationPeriodData(
                userId: 'user-2',
                slot: 1,
                startDay: 20261005,
                endDay: 20261018,
              ),
            ),
          ];
        },
        documentSaver: _noOpSaver,
        documentDeleter: _noOpDeleter,
      );

      await expectLater(
        gateway.loadForUser(userId: 'user-1'),
        throwsStateError,
      );
    });

    test('rejects malformed vacation period document', () async {
      final gateway = VacationPeriodFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          return <VacationPeriodDocument>[
            (
              id: '${userId}__1',
              data: <String, dynamic>{'userId': userId, 'slot': 1},
            ),
          ];
        },
        documentSaver: _noOpSaver,
        documentDeleter: _noOpDeleter,
      );

      await expectLater(
        gateway.loadForUser(userId: 'user-1'),
        throwsStateError,
      );
    });

    test('watch maps and sorts vacation periods', () async {
      String? watchedUserId;

      final gateway = VacationPeriodFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          return const <VacationPeriodDocument>[];
        },
        documentsWatcher: ({required String userId}) {
          watchedUserId = userId;

          return Stream<List<VacationPeriodDocument>>.value(
            <VacationPeriodDocument>[
              (
                id: '${userId}__6',
                data: _vacationPeriodData(
                  userId: userId,
                  slot: 6,
                  startDay: 20261220,
                  endDay: 20261230,
                ),
              ),
              (
                id: '${userId}__2',
                data: _vacationPeriodData(
                  userId: userId,
                  slot: 2,
                  startDay: 20261101,
                  endDay: 20261110,
                ),
              ),
            ],
          );
        },
        documentSaver: _noOpSaver,
        documentDeleter: _noOpDeleter,
      );

      final periods = await gateway.watchForUser(userId: ' user-1 ').first;

      expect(watchedUserId, 'user-1');
      expect(periods.map((period) => period.slot), <int>[2, 6]);
    });

    test('watch without configured watcher throws state error', () async {
      final gateway = VacationPeriodFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          return const <VacationPeriodDocument>[];
        },
        documentSaver: _noOpSaver,
        documentDeleter: _noOpDeleter,
      );

      await expectLater(
        gateway.watchForUser(userId: 'user-1').toList(),
        throwsStateError,
      );
    });

    test('save normalizes user id and calendar dates', () async {
      String? savedDocumentId;
      Map<String, dynamic>? savedData;

      final gateway = VacationPeriodFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          return const <VacationPeriodDocument>[];
        },
        documentSaver:
            ({
              required String documentId,
              required Map<String, dynamic> data,
            }) async {
              savedDocumentId = documentId;
              savedData = data;
            },
        documentDeleter: _noOpDeleter,
      );

      await gateway.save(
        VacationPeriod(
          userId: ' user-1 ',
          slot: 2,
          startDate: DateTime(2026, 10, 5, 23, 30),
          endDate: DateTime(2026, 10, 18, 1, 15),
        ),
      );

      expect(savedDocumentId, 'user-1__2');
      expect(savedData?['schemaVersion'], 1);
      expect(savedData?['userId'], 'user-1');
      expect(savedData?['slot'], 2);
      expect(savedData?['startDay'], 20261005);
      expect(savedData?['endDay'], 20261018);
      expect(savedData?['updatedAt'], isA<FieldValue>());
    });

    test('delete uses normalized deterministic document id', () async {
      String? deletedDocumentId;

      final gateway = VacationPeriodFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          return const <VacationPeriodDocument>[];
        },
        documentSaver: _noOpSaver,
        documentDeleter: ({required String documentId}) async {
          deletedDocumentId = documentId;
        },
      );

      await gateway.delete(userId: ' user-1 ', slot: 6);

      expect(deletedDocumentId, 'user-1__6');
    });

    test('delete rejects slot outside one to six', () async {
      final gateway = VacationPeriodFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          return const <VacationPeriodDocument>[];
        },
        documentSaver: _noOpSaver,
        documentDeleter: _noOpDeleter,
      );

      await expectLater(
        gateway.delete(userId: 'user-1', slot: 7),
        throwsArgumentError,
      );
    });
  });
}

Future<void> _noOpSaver({
  required String documentId,
  required Map<String, dynamic> data,
}) async {}

Future<void> _noOpDeleter({required String documentId}) async {}

Map<String, dynamic> _vacationPeriodData({
  required String userId,
  required int slot,
  required int startDay,
  required int endDay,
}) {
  return <String, dynamic>{
    'schemaVersion': 1,
    'userId': userId,
    'slot': slot,
    'startDay': startDay,
    'endDay': endDay,
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 17, 12)),
  };
}
