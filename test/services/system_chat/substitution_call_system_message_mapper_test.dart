import 'package:epistola/domain/models/epistola_system_message.dart';
import 'package:epistola/domain/models/substitution_confirmed_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/system_chat/substitution_call_system_message_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = SubstitutionCallSystemMessageMapper();

  test('maps confirmed day call to Epistola system message', () {
    final calledAt = DateTime.utc(2026, 9, 4, 16, 42);

    final call = SubstitutionConfirmedCall(
      callId: '17',
      userId: 'user-1',
      revision: 17,
      calledByUserId: 'brigadier-1',
      calledAt: calledAt,
      finalizedAt: calledAt.add(const Duration(seconds: 6)),
      shift: SubstitutionShift(
        year: 2026,
        month: 9,
        day: 5,
        kind: SubstitutionShiftKind.day,
      ),
    );

    final message = mapper.map(call);

    expect(message.id, 'substitutionCall:17');

    expect(message.source, EpistolaSystemMessageSource.substitutionCall);

    expect(message.sourceId, '17');

    expect(
      message.text,
      'Вы вызваны на дневную смену '
      '05.09.2026 в 08:00',
    );

    expect(message.createdAt, calledAt);
  });

  test('maps confirmed night call to Epistola system message', () {
    final calledAt = DateTime.utc(2026, 9, 4, 17);

    final call = SubstitutionConfirmedCall(
      callId: '18',
      userId: 'user-1',
      revision: 18,
      calledByUserId: 'brigadier-1',
      calledAt: calledAt,
      finalizedAt: calledAt.add(const Duration(seconds: 6)),
      shift: SubstitutionShift(
        year: 2026,
        month: 9,
        day: 6,
        kind: SubstitutionShiftKind.night,
      ),
    );

    final message = mapper.map(call);

    expect(message.id, 'substitutionCall:18');

    expect(
      message.text,
      'Вы вызваны на ночную смену '
      '06.09.2026 в 20:00',
    );

    expect(message.createdAt, calledAt);
  });

  test('uses source-scoped id instead of raw event id', () {
    final calledAt = DateTime.utc(2026, 9, 4, 18);

    final call = SubstitutionConfirmedCall(
      callId: '7',
      userId: 'user-1',
      revision: 7,
      calledByUserId: 'brigadier-1',
      calledAt: calledAt,
      finalizedAt: calledAt.add(const Duration(seconds: 6)),
      shift: SubstitutionShift(
        year: 2026,
        month: 9,
        day: 5,
        kind: SubstitutionShiftKind.day,
      ),
    );

    final message = mapper.map(call);

    expect(message.sourceId, '7');

    expect(message.id, 'substitutionCall:7');

    expect(message.id, isNot(message.sourceId));
  });
}
