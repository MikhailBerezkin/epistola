import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/services/spaces/substitution/substitution_confirmed_call_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads confirmed calls for normalized user and sorts newest first',
    () async {
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
                userId: 'user-1',
                finalizedAt: DateTime.utc(2026, 9, 4, 10, 0, 6),
              ),
            ),
            (
              id: '2',
              data: _confirmedCallData(
                callId: '2',
                revision: 2,
                userId: 'user-1',
                finalizedAt: DateTime.utc(2026, 9, 4, 11, 0, 6),
              ),
            ),
          ];
        },
      );

      final calls = await gateway.loadForUser(userId: ' user-1 ');

      expect(loadedUserId, 'user-1');

      expect(calls.map((call) => call.callId), <String>['2', '1']);
    },
  );

  test(
    'rejects confirmed call whose document id differs from callId',
    () async {
      final gateway = SubstitutionConfirmedCallFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          return <SubstitutionConfirmedCallDocument>[
            (
              id: '99',
              data: _confirmedCallData(
                callId: '1',
                revision: 1,
                userId: userId,
                finalizedAt: DateTime.utc(2026, 9, 4, 10, 0, 6),
              ),
            ),
          ];
        },
      );

      await expectLater(
        gateway.loadForUser(userId: 'user-1'),
        throwsStateError,
      );
    },
  );

  test('rejects malformed confirmed call document', () async {
    final gateway = SubstitutionConfirmedCallFirestoreGateway(
      documentsLoader: ({required String userId}) async {
        return <SubstitutionConfirmedCallDocument>[
          (id: '1', data: <String, dynamic>{'callId': '1', 'userId': userId}),
        ];
      },
    );

    await expectLater(gateway.loadForUser(userId: 'user-1'), throwsStateError);
  });

  test('watch maps every confirmed call snapshot', () async {
    String? watchedUserId;

    final gateway = SubstitutionConfirmedCallFirestoreGateway(
      documentsLoader: ({required String userId}) async {
        return const <SubstitutionConfirmedCallDocument>[];
      },
      documentsWatcher: ({required String userId}) {
        watchedUserId = userId;

        return Stream<List<SubstitutionConfirmedCallDocument>>.fromIterable([
          <SubstitutionConfirmedCallDocument>[
            (
              id: '1',
              data: _confirmedCallData(
                callId: '1',
                revision: 1,
                userId: userId,
                finalizedAt: DateTime.utc(2026, 9, 4, 10, 0, 6),
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
                finalizedAt: DateTime.utc(2026, 9, 4, 10, 0, 6),
              ),
            ),
            (
              id: '2',
              data: _confirmedCallData(
                callId: '2',
                revision: 2,
                userId: userId,
                finalizedAt: DateTime.utc(2026, 9, 4, 11, 0, 6),
              ),
            ),
          ],
        ]);
      },
    );

    final states = await gateway
        .watchForUser(userId: ' user-1 ')
        .take(2)
        .toList();

    expect(watchedUserId, 'user-1');

    expect(states[0].map((call) => call.callId), <String>['1']);

    expect(states[1].map((call) => call.callId), <String>['2', '1']);
  });

  test('watch without configured watcher throws state error', () async {
    final gateway = SubstitutionConfirmedCallFirestoreGateway(
      documentsLoader: ({required String userId}) async {
        return const <SubstitutionConfirmedCallDocument>[];
      },
    );

    await expectLater(
      gateway.watchForUser(userId: 'user-1').toList(),
      throwsStateError,
    );
  });
}

Map<String, dynamic> _confirmedCallData({
  required String callId,
  required int revision,
  required String userId,
  required DateTime finalizedAt,
}) {
  final calledAt = finalizedAt.subtract(const Duration(seconds: 6));

  return <String, dynamic>{
    'schemaVersion': 1,
    'callId': callId,
    'userId': userId,
    'revision': revision,
    'calledByUserId': 'brigadier-1',
    'calledAt': Timestamp.fromDate(calledAt),
    'finalizedAt': Timestamp.fromDate(finalizedAt),
    'shiftYear': 2026,
    'shiftMonth': 9,
    'shiftDay': 5,
    'shiftKind': 'day',
  };
}
