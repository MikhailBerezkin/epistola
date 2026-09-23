import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/calendar/calendar_additional_shift_service.dart';
import 'package:epistola/services/spaces/substitution/substitution_confirmed_call_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarAdditionalShiftService', () {
    test('loads and projects confirmed calls for user', () async {
      String? loadedUserId;

      final gateway = SubstitutionConfirmedCallFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          loadedUserId = userId;

          return <SubstitutionConfirmedCallDocument>[
            (
              id: '1',
              data: _confirmedCallData(
                callId: '1',
                revision: 1,
                userId: userId,
                year: 2026,
                month: 9,
                day: 24,
                kind: SubstitutionShiftKind.day,
              ),
            ),
          ];
        },
      );

      final service = CalendarAdditionalShiftService(gateway);

      final events = await service.loadForUser(userId: ' user-1 ');

      expect(loadedUserId, 'user-1');
      expect(events, hasLength(1));

      final event = events.single;

      expect(event.sourceCallId, '1');
      expect(event.date, DateTime(2026, 9, 24));
      expect(event.startAt, DateTime(2026, 9, 24, 8));
      expect(event.endAt, DateTime(2026, 9, 24, 20));
    });

    test('watch projects every confirmed call snapshot', () async {
      final gateway = SubstitutionConfirmedCallFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          return const <SubstitutionConfirmedCallDocument>[];
        },
        documentsWatcher: ({required String userId}) {
          return Stream<List<SubstitutionConfirmedCallDocument>>.fromIterable([
            <SubstitutionConfirmedCallDocument>[
              (
                id: '1',
                data: _confirmedCallData(
                  callId: '1',
                  revision: 1,
                  userId: userId,
                  year: 2026,
                  month: 9,
                  day: 24,
                  kind: SubstitutionShiftKind.day,
                ),
              ),
            ],
            <SubstitutionConfirmedCallDocument>[
              (
                id: '1',
                data: _confirmedCallData(
                  callId: '1',
                  revision: 1,
                  userId: userId,
                  year: 2026,
                  month: 9,
                  day: 24,
                  kind: SubstitutionShiftKind.day,
                ),
              ),
              (
                id: '2',
                data: _confirmedCallData(
                  callId: '2',
                  revision: 2,
                  userId: userId,
                  year: 2026,
                  month: 9,
                  day: 25,
                  kind: SubstitutionShiftKind.night,
                ),
              ),
            ],
          ]);
        },
      );

      final service = CalendarAdditionalShiftService(gateway);

      final states = await service
          .watchForUser(userId: 'user-1')
          .take(2)
          .toList();

      expect(states, hasLength(2));

      expect(states[0].map((event) => event.sourceCallId), <String>['1']);

      expect(states[1].map((event) => event.sourceCallId), <String>['1', '2']);

      expect(states[1][1].startAt, DateTime(2026, 9, 25, 20));

      expect(states[1][1].endAt, DateTime(2026, 9, 26, 8));
    });

    test('propagates missing watcher state error', () async {
      final gateway = SubstitutionConfirmedCallFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          return const <SubstitutionConfirmedCallDocument>[];
        },
      );

      final service = CalendarAdditionalShiftService(gateway);

      await expectLater(
        service.watchForUser(userId: 'user-1').toList(),
        throwsStateError,
      );
    });
  });
}

Map<String, dynamic> _confirmedCallData({
  required String callId,
  required int revision,
  required String userId,
  required int year,
  required int month,
  required int day,
  required SubstitutionShiftKind kind,
}) {
  final calledAt = DateTime.utc(2026, 9, 23, 12);
  final finalizedAt = calledAt.add(const Duration(seconds: 3));

  return <String, dynamic>{
    'schemaVersion': 1,
    'callId': callId,
    'userId': userId,
    'revision': revision,
    'calledByUserId': 'brigadier-1',
    'calledAt': Timestamp.fromDate(calledAt),
    'finalizedAt': Timestamp.fromDate(finalizedAt),
    'shiftYear': year,
    'shiftMonth': month,
    'shiftDay': day,
    'shiftKind': switch (kind) {
      SubstitutionShiftKind.day => 'day',
      SubstitutionShiftKind.night => 'night',
    },
  };
}
