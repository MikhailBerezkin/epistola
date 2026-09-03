import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_board_firestore_gateway.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_dependencies.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_hidden_messages_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('wires board and local hidden preferences into presentation', () async {
    final now = DateTime.utc(2026, 9, 3, 12);

    final hiddenMessagesPreferences = SpacesBarHiddenMessagesPreferences();

    await hiddenMessagesPreferences.hideMessage(
      userId: 'user-1',
      messageId: '1',
    );

    final gateway = SpacesBarBoardFirestoreGateway(
      documentReader: () async {
        return <String, dynamic>{
          'schemaVersion': 1,
          'revision': 1,
          'messages': <String, dynamic>{
            '1': <String, dynamic>{
              'text': 'Закреплённое сообщение',
              'lifetime': 'untilCancelled',
              'createdByUserId': 'owner-1',
              'createdAt': Timestamp.fromDate(now),
            },
          },
          'updatedAt': Timestamp.fromDate(now),
        };
      },
    );

    final service = createSpacesBarPresentationService(
      boardGateway: gateway,
      hiddenMessagesPreferences: hiddenMessagesPreferences,
      clock: () => now,
    );

    final state = await service.load(userId: 'user-1');

    expect(state.activeMessageCount, 1);
    expect(state.activeMessages.single.id, '1');

    expect(state.hiddenMessageIds, <String>{'1'});
    expect(state.visibleMessages, isEmpty);
    expect(state.hasVisibleMessages, isFalse);
  });
}
