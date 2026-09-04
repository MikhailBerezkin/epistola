import 'dart:async';

import 'package:epistola/domain/models/spaces_bar_board.dart';
import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/domain/models/substitution_confirmed_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_presentation_item.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_presentation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nowUtc = DateTime.utc(2026, 9, 4, 12);

  final nowLocal = DateTime(2026, 9, 4, 15);

  test('load combines general and personal items '
      'without changing general 3-slot count', () async {
    final board = _board([
      _message(id: '7', createdAt: DateTime.utc(2026, 9, 4, 10)),
    ]);

    final call = _call(
      callId: '7',
      revision: 7,
      finalizedAt: DateTime.utc(2026, 9, 4, 11),
    );

    final service = SpacesBarPresentationService(
      boardLoader: () async => board,
      hiddenMessageIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      messageHider:
          ({required String userId, required String messageId}) async {},
      confirmedCallsLoader: ({required String userId}) async {
        return <SubstitutionConfirmedCall>[call];
      },
      hiddenSubstitutionCallIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      substitutionCallHider:
          ({required String userId, required String callId}) async {},
      substitutionCallTextBuilder: (call) => 'Вызов ${call.callId}',
      clock: () => nowUtc,
      localClock: () => nowLocal,
    );

    final state = await service.load(userId: 'user-1');

    expect(state.activeMessageCount, 1);

    expect(state.activeMessages.single.id, '7');

    expect(state.activeSubstitutionCallCount, 1);

    expect(state.presentationItems.map((item) => item.presentationId), <String>[
      'substitution:7',
      'general:7',
    ]);

    expect(
      state.presentationItems.first.source,
      SpacesBarPresentationItemSource.substitutionCall,
    );

    expect(state.presentationItems.first.text, 'Вызов 7');

    expect(state.hasPresentationItems, isTrue);
  });

  test('watch emits when either realtime source changes', () async {
    final boardController = StreamController<SpacesBarBoard>();

    final callsController = StreamController<List<SubstitutionConfirmedCall>>();

    final initialBoard = _board([
      _message(id: '1', createdAt: DateTime.utc(2026, 9, 4, 10)),
    ]);

    final updatedBoard = _board([
      _message(id: '3', createdAt: DateTime.utc(2026, 9, 4, 12)),
      _message(id: '1', createdAt: DateTime.utc(2026, 9, 4, 10)),
    ]);

    final call = _call(
      callId: '2',
      revision: 2,
      finalizedAt: DateTime.utc(2026, 9, 4, 11),
    );

    final service = SpacesBarPresentationService(
      boardLoader: () async => initialBoard,
      boardWatcher: () => boardController.stream,
      hiddenMessageIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      messageHider:
          ({required String userId, required String messageId}) async {},
      confirmedCallsWatcher: ({required String userId}) {
        return callsController.stream;
      },
      hiddenSubstitutionCallIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      substitutionCallHider:
          ({required String userId, required String callId}) async {},
      substitutionCallTextBuilder: (call) => 'Вызов ${call.callId}',
      clock: () => nowUtc,
      localClock: () => nowLocal,
    );

    final statesFuture = service.watch(userId: 'user-1').take(3).toList();

    boardController.add(initialBoard);

    callsController.add(const <SubstitutionConfirmedCall>[]);

    await Future<void>.delayed(Duration.zero);

    callsController.add([call]);

    await Future<void>.delayed(Duration.zero);

    boardController.add(updatedBoard);

    final states = await statesFuture;

    expect(states, hasLength(3));

    expect(
      states[0].presentationItems.map((item) => item.presentationId),
      <String>['general:1'],
    );

    expect(
      states[1].presentationItems.map((item) => item.presentationId),
      <String>['substitution:2', 'general:1'],
    );

    expect(
      states[2].presentationItems.map((item) => item.presentationId),
      <String>['general:3', 'substitution:2', 'general:1'],
    );

    await boardController.close();
    await callsController.close();
  });

  test('hiding general message keeps personal call visible', () async {
    final board = _board([
      _message(id: '7', createdAt: DateTime.utc(2026, 9, 4, 10)),
    ]);

    final call = _call(
      callId: '7',
      revision: 7,
      finalizedAt: DateTime.utc(2026, 9, 4, 11),
    );

    final service = SpacesBarPresentationService(
      boardLoader: () async => board,
      hiddenMessageIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      messageHider:
          ({required String userId, required String messageId}) async {},
      confirmedCallsLoader: ({required String userId}) async {
        return [call];
      },
      hiddenSubstitutionCallIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      substitutionCallHider:
          ({required String userId, required String callId}) async {},
      substitutionCallTextBuilder: (call) => 'Вызов ${call.callId}',
      clock: () => nowUtc,
      localClock: () => nowLocal,
    );

    final initial = await service.load(userId: 'user-1');

    final next = await service.hideMessage(
      userId: 'user-1',
      messageId: '7',
      currentState: initial,
    );

    expect(next.visibleMessages, isEmpty);

    expect(next.visibleSubstitutionCalls, hasLength(1));

    expect(next.presentationItems.map((item) => item.presentationId), <String>[
      'substitution:7',
    ]);
  });

  test('hiding personal call keeps same-numbered '
      'general message visible', () async {
    String? hiddenUserId;
    String? hiddenCallId;

    final board = _board([
      _message(id: '7', createdAt: DateTime.utc(2026, 9, 4, 10)),
    ]);

    final call = _call(
      callId: '7',
      revision: 7,
      finalizedAt: DateTime.utc(2026, 9, 4, 11),
    );

    final service = SpacesBarPresentationService(
      boardLoader: () async => board,
      hiddenMessageIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      messageHider:
          ({required String userId, required String messageId}) async {},
      confirmedCallsLoader: ({required String userId}) async {
        return [call];
      },
      hiddenSubstitutionCallIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      substitutionCallHider:
          ({required String userId, required String callId}) async {
            hiddenUserId = userId;
            hiddenCallId = callId;
          },
      substitutionCallTextBuilder: (call) => 'Вызов ${call.callId}',
      clock: () => nowUtc,
      localClock: () => nowLocal,
    );

    final initial = await service.load(userId: 'user-1');

    final next = await service.hideSubstitutionCall(
      userId: ' user-1 ',
      callId: ' 7 ',
      currentState: initial,
    );

    expect(hiddenUserId, 'user-1');

    expect(hiddenCallId, '7');

    expect(next.activeSubstitutionCalls, hasLength(1));

    expect(next.visibleSubstitutionCalls, isEmpty);

    expect(next.visibleMessages, hasLength(1));

    expect(next.presentationItems.map((item) => item.presentationId), <String>[
      'general:7',
    ]);
  });

  test('local refresh removes personal call when shift starts', () async {
    final nowUtc = DateTime.utc(2026, 9, 5, 4, 59);

    var nowLocal = DateTime(2026, 9, 5, 7, 59);

    final board = _board(const <SpacesBarMessage>[]);

    final call = _call(
      callId: '7',
      revision: 7,
      finalizedAt: DateTime.utc(2026, 9, 4, 10),
    );

    final service = SpacesBarPresentationService(
      boardLoader: () async => board,
      hiddenMessageIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      messageHider:
          ({required String userId, required String messageId}) async {},
      confirmedCallsLoader: ({required String userId}) async {
        return [call];
      },
      hiddenSubstitutionCallIdsLoader: ({required String userId}) async {
        return <String>{};
      },
      substitutionCallHider:
          ({required String userId, required String callId}) async {},
      substitutionCallTextBuilder: (call) => 'Вызов ${call.callId}',
      clock: () => nowUtc,
      localClock: () => nowLocal,
    );

    final beforeShift = await service.load(userId: 'user-1');

    expect(beforeShift.visibleSubstitutionCalls, hasLength(1));

    expect(beforeShift.presentationItems, hasLength(1));

    expect(beforeShift.nextSubstitutionExpiryAtLocal, DateTime(2026, 9, 5, 8));

    nowLocal = DateTime(2026, 9, 5, 8);

    final atShiftStart = service.refreshForCurrentTime(
      currentState: beforeShift,
    );

    expect(atShiftStart.activeSubstitutionCalls, isEmpty);

    expect(atShiftStart.visibleSubstitutionCalls, isEmpty);

    expect(atShiftStart.presentationItems, isEmpty);

    expect(atShiftStart.nextSubstitutionExpiryAtLocal, isNull);
  });
}

SpacesBarBoard _board(List<SpacesBarMessage> messages) {
  final board = SpacesBarBoard.tryCreate(revision: 10, messages: messages);

  expect(board, isNotNull);

  return board!;
}

SpacesBarMessage _message({required String id, required DateTime createdAt}) {
  final message = SpacesBarMessage.tryCreate(
    id: id,
    text: 'Сообщение $id',
    lifetime: SpacesBarMessageLifetime.untilCancelled,
    createdByUserId: 'owner-1',
    createdAt: createdAt,
  );

  expect(message, isNotNull);

  return message!;
}

SubstitutionConfirmedCall _call({
  required String callId,
  required int revision,
  required DateTime finalizedAt,
}) {
  return SubstitutionConfirmedCall(
    callId: callId,
    userId: 'user-1',
    revision: revision,
    calledByUserId: 'brigadier-1',
    calledAt: finalizedAt.subtract(const Duration(seconds: 6)),
    finalizedAt: finalizedAt,
    shift: SubstitutionShift(
      year: 2026,
      month: 9,
      day: 5,
      kind: SubstitutionShiftKind.day,
    ),
  );
}
