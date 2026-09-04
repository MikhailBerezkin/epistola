import 'package:epistola/domain/models/spaces_bar_message.dart';
import 'package:epistola/domain/models/substitution_confirmed_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_presentation_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates general presentation item from spaces bar message', () {
    final message = _generalMessage(id: '7');

    final item = SpacesBarPresentationItem.general(message: message);

    expect(item.source, SpacesBarPresentationItemSource.generalMessage);

    expect(item.sourceId, '7');
    expect(item.presentationId, 'general:7');

    expect(item.text, 'Общее сообщение 7');

    expect(item.publishedAt, message.createdAt);

    expect(item.generalMessage, same(message));

    expect(item.substitutionCall, isNull);

    expect(item.isGeneralMessage, isTrue);
    expect(item.isSubstitutionCall, isFalse);

    expect(item.generalMessageId, '7');
    expect(item.substitutionCallId, isNull);
  });

  test('creates substitution presentation item from confirmed call', () {
    final call = _confirmedCall(callId: '7');

    final item = SpacesBarPresentationItem.substitution(
      call: call,
      text: ' Вызов на смену ',
    );

    expect(item.source, SpacesBarPresentationItemSource.substitutionCall);

    expect(item.sourceId, '7');
    expect(item.presentationId, 'substitution:7');

    expect(item.text, 'Вызов на смену');

    expect(item.publishedAt, call.finalizedAt);

    expect(item.generalMessage, isNull);

    expect(item.substitutionCall, same(call));

    expect(item.isGeneralMessage, isFalse);
    expect(item.isSubstitutionCall, isTrue);

    expect(item.generalMessageId, isNull);
    expect(item.substitutionCallId, '7');
  });

  test('general and substitution numeric ids do not collide', () {
    final general = SpacesBarPresentationItem.general(
      message: _generalMessage(id: '7'),
    );

    final substitution = SpacesBarPresentationItem.substitution(
      call: _confirmedCall(callId: '7'),
      text: 'Вызов',
    );

    expect(general.sourceId, substitution.sourceId);

    expect(general.presentationId, isNot(substitution.presentationId));

    expect(general.presentationId, 'general:7');

    expect(substitution.presentationId, 'substitution:7');
  });

  test('rejects empty substitution presentation text', () {
    expect(
      () => SpacesBarPresentationItem.substitution(
        call: _confirmedCall(callId: '1'),
        text: '   ',
      ),
      throwsArgumentError,
    );
  });
}

SpacesBarMessage _generalMessage({required String id}) {
  final message = SpacesBarMessage.tryCreate(
    id: id,
    text: 'Общее сообщение $id',
    lifetime: SpacesBarMessageLifetime.untilCancelled,
    createdByUserId: 'owner-1',
    createdAt: DateTime.utc(2026, 9, 4, 10),
  );

  expect(message, isNotNull);

  return message!;
}

SubstitutionConfirmedCall _confirmedCall({required String callId}) {
  final revision = int.parse(callId);

  return SubstitutionConfirmedCall(
    callId: callId,
    userId: 'user-1',
    revision: revision,
    calledByUserId: 'brigadier-1',
    calledAt: DateTime.utc(2026, 9, 4, 10),
    finalizedAt: DateTime.utc(2026, 9, 4, 10, 0, 6),
    shift: SubstitutionShift(
      year: 2026,
      month: 9,
      day: 5,
      kind: SubstitutionShiftKind.day,
    ),
  );
}
