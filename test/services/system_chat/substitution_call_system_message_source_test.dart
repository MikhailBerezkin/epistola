import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/services/spaces/substitution/substitution_confirmed_call_firestore_gateway.dart';
import 'package:epistola/services/system_chat/substitution_call_system_message_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'load maps confirmed calls and sorts system messages old to new',
    () async {
      String? loadedUserId;

      final gateway = SubstitutionConfirmedCallFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          loadedUserId = userId;

          return <SubstitutionConfirmedCallDocument>[
            (
              id: '2',
              data: _confirmedCallData(
                callId: '2',
                revision: 2,
                userId: userId,
                calledAt: DateTime.utc(2026, 9, 4, 11),
                finalizedAt: DateTime.utc(2026, 9, 4, 11, 0, 6),
              ),
            ),
            (
              id: '1',
              data: _confirmedCallData(
                callId: '1',
                revision: 1,
                userId: userId,
                calledAt: DateTime.utc(2026, 9, 4, 10),
                finalizedAt: DateTime.utc(2026, 9, 4, 10, 0, 6),
              ),
            ),
          ];
        },
      );

      final source = SubstitutionCallSystemMessageSource(gateway: gateway);

      final messages = await source.load(userId: ' user-1 ');

      expect(loadedUserId, 'user-1');

      expect(messages.map((message) => message.id), <String>[
        'substitutionCall:1',
        'substitutionCall:2',
      ]);

      expect(messages.map((message) => message.createdAt), <DateTime>[
        DateTime.utc(2026, 9, 4, 10),
        DateTime.utc(2026, 9, 4, 11),
      ]);
    },
  );

  test('load uses deterministic id tie-break for equal event time', () async {
    final calledAt = DateTime.utc(2026, 9, 4, 10);

    final gateway = SubstitutionConfirmedCallFirestoreGateway(
      documentsLoader: ({required String userId}) async {
        return <SubstitutionConfirmedCallDocument>[
          (
            id: '8',
            data: _confirmedCallData(
              callId: '8',
              revision: 8,
              userId: userId,
              calledAt: calledAt,
              finalizedAt: calledAt.add(const Duration(seconds: 8)),
            ),
          ),
          (
            id: '7',
            data: _confirmedCallData(
              callId: '7',
              revision: 7,
              userId: userId,
              calledAt: calledAt,
              finalizedAt: calledAt.add(const Duration(seconds: 7)),
            ),
          ),
        ];
      },
    );

    final source = SubstitutionCallSystemMessageSource(gateway: gateway);

    final messages = await source.load(userId: 'user-1');

    expect(messages.map((message) => message.id), <String>[
      'substitutionCall:7',
      'substitutionCall:8',
    ]);
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
                calledAt: DateTime.utc(2026, 9, 4, 10),
                finalizedAt: DateTime.utc(2026, 9, 4, 10, 0, 6),
              ),
            ),
          ],
          <SubstitutionConfirmedCallDocument>[
            (
              id: '2',
              data: _confirmedCallData(
                callId: '2',
                revision: 2,
                userId: userId,
                calledAt: DateTime.utc(2026, 9, 4, 11),
                finalizedAt: DateTime.utc(2026, 9, 4, 11, 0, 6),
              ),
            ),
            (
              id: '1',
              data: _confirmedCallData(
                callId: '1',
                revision: 1,
                userId: userId,
                calledAt: DateTime.utc(2026, 9, 4, 10),
                finalizedAt: DateTime.utc(2026, 9, 4, 10, 0, 6),
              ),
            ),
          ],
        ]);
      },
    );

    final source = SubstitutionCallSystemMessageSource(gateway: gateway);

    final states = await source.watch(userId: ' user-1 ').take(2).toList();

    expect(watchedUserId, 'user-1');

    expect(states[0].map((message) => message.id), <String>[
      'substitutionCall:1',
    ]);

    expect(states[1].map((message) => message.id), <String>[
      'substitutionCall:1',
      'substitutionCall:2',
    ]);
  });
}

Map<String, dynamic> _confirmedCallData({
  required String callId,
  required int revision,
  required String userId,
  required DateTime calledAt,
  required DateTime finalizedAt,
}) {
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
