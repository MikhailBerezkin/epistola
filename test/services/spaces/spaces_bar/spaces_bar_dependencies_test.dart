import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_board_firestore_gateway.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_dependencies.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_hidden_messages_preferences.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_hidden_substitution_calls_preferences.dart';
import 'package:epistola/services/spaces/substitution/substitution_confirmed_call_firestore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('wires board and local hidden preferences into presentation', () async {
    final nowUtc = DateTime.utc(2026, 9, 3, 12);

    final nowLocal = DateTime(2026, 9, 3, 15);

    final hiddenMessagesPreferences = SpacesBarHiddenMessagesPreferences();

    await hiddenMessagesPreferences.hideMessage(
      userId: 'user-1',
      messageId: '1',
    );

    final boardGateway = SpacesBarBoardFirestoreGateway(
      documentReader: () async {
        return <String, dynamic>{
          'schemaVersion': 1,
          'revision': 1,
          'messages': <String, dynamic>{
            '1': <String, dynamic>{
              'text': 'Закреплённое сообщение',
              'lifetime': 'untilCancelled',
              'createdByUserId': 'owner-1',
              'createdAt': Timestamp.fromDate(nowUtc),
            },
          },
          'updatedAt': Timestamp.fromDate(nowUtc),
        };
      },
    );

    final confirmedCallGateway = SubstitutionConfirmedCallFirestoreGateway(
      documentsLoader: ({required String userId}) async {
        return const <SubstitutionConfirmedCallDocument>[];
      },
    );

    final service = createSpacesBarPresentationService(
      boardGateway: boardGateway,
      hiddenMessagesPreferences: hiddenMessagesPreferences,
      confirmedCallGateway: confirmedCallGateway,
      hiddenSubstitutionCallsPreferences:
          SpacesBarHiddenSubstitutionCallsPreferences(),
      clock: () => nowUtc,
      localClock: () => nowLocal,
    );

    final state = await service.load(userId: 'user-1');

    expect(state.activeMessageCount, 1);

    expect(state.activeMessages.single.id, '1');

    expect(state.hiddenMessageIds, <String>{'1'});

    expect(state.visibleMessages, isEmpty);

    expect(state.activeSubstitutionCalls, isEmpty);

    expect(state.presentationItems, isEmpty);

    expect(state.hasVisibleMessages, isFalse);
  });

  test(
    'wires confirmed calls and separate personal hide preferences',
    () async {
      final nowUtc = DateTime.utc(2026, 9, 4, 12);

      final nowLocal = DateTime(2026, 9, 4, 15);

      final boardGateway = SpacesBarBoardFirestoreGateway(
        documentReader: () async {
          return <String, dynamic>{
            'schemaVersion': 1,
            'revision': 0,
            'messages': <String, dynamic>{},
            'updatedAt': Timestamp.fromDate(nowUtc),
          };
        },
      );

      String? requestedUserId;

      final confirmedCallGateway = SubstitutionConfirmedCallFirestoreGateway(
        documentsLoader: ({required String userId}) async {
          requestedUserId = userId;

          return <SubstitutionConfirmedCallDocument>[
            (
              id: '7',
              data: <String, dynamic>{
                'schemaVersion': 1,
                'callId': '7',
                'userId': userId,
                'revision': 7,
                'calledByUserId': 'brigadier-1',
                'calledAt': Timestamp.fromDate(DateTime.utc(2026, 9, 4, 10)),
                'finalizedAt': Timestamp.fromDate(
                  DateTime.utc(2026, 9, 4, 10, 0, 6),
                ),
                'shiftYear': 2026,
                'shiftMonth': 9,
                'shiftDay': 5,
                'shiftKind': 'day',
              },
            ),
          ];
        },
      );

      final hiddenSubstitutionCallsPreferences =
          SpacesBarHiddenSubstitutionCallsPreferences();

      final service = createSpacesBarPresentationService(
        boardGateway: boardGateway,
        confirmedCallGateway: confirmedCallGateway,
        hiddenSubstitutionCallsPreferences: hiddenSubstitutionCallsPreferences,
        clock: () => nowUtc,
        localClock: () => nowLocal,
      );

      final initial = await service.load(userId: ' user-1 ');

      expect(requestedUserId, 'user-1');

      expect(initial.activeMessageCount, 0);

      expect(initial.activeSubstitutionCalls, hasLength(1));

      expect(initial.visibleSubstitutionCalls, hasLength(1));

      expect(initial.presentationItems, hasLength(1));

      expect(initial.presentationItems.single.presentationId, 'substitution:7');

      final hidden = await service.hideSubstitutionCall(
        userId: 'user-1',
        callId: '7',
        currentState: initial,
      );

      expect(hidden.activeSubstitutionCalls, hasLength(1));

      expect(hidden.visibleSubstitutionCalls, isEmpty);

      expect(hidden.presentationItems, isEmpty);

      final storedIds = await hiddenSubstitutionCallsPreferences
          .loadHiddenCallIds(userId: 'user-1');

      expect(storedIds, <String>{'7'});
    },
  );
}
