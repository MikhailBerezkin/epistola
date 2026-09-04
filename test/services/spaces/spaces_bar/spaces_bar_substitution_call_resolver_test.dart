import 'package:epistola/domain/models/substitution_confirmed_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/spaces_bar/spaces_bar_substitution_call_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = SpacesBarSubstitutionCallResolver();

  test('night call remains active until local 20:00', () {
    final call = _call(
      callId: '1',
      revision: 1,
      finalizedAt: DateTime.utc(2026, 9, 4, 10),
      shift: SubstitutionShift(
        year: 2026,
        month: 9,
        day: 4,
        kind: SubstitutionShiftKind.night,
      ),
    );

    final beforeShift = resolver.resolve(
      calls: <SubstitutionConfirmedCall>[call],
      hiddenCallIds: <String>{},
      nowLocal: DateTime(2026, 9, 4, 19, 59, 59),
    );

    expect(beforeShift.visibleCalls, hasLength(1));

    final atShiftStart = resolver.resolve(
      calls: <SubstitutionConfirmedCall>[call],
      hiddenCallIds: <String>{},
      nowLocal: DateTime(2026, 9, 4, 20),
    );

    expect(atShiftStart.activeCalls, isEmpty);

    expect(atShiftStart.visibleCalls, isEmpty);
  });

  test('day call remains active until local 08:00', () {
    final call = _call(
      callId: '2',
      revision: 2,
      finalizedAt: DateTime.utc(2026, 9, 4, 10),
      shift: SubstitutionShift(
        year: 2026,
        month: 9,
        day: 5,
        kind: SubstitutionShiftKind.day,
      ),
    );

    final beforeShift = resolver.resolve(
      calls: <SubstitutionConfirmedCall>[call],
      hiddenCallIds: <String>{},
      nowLocal: DateTime(2026, 9, 5, 7, 59, 59),
    );

    expect(beforeShift.visibleCalls, hasLength(1));

    final atShiftStart = resolver.resolve(
      calls: <SubstitutionConfirmedCall>[call],
      hiddenCallIds: <String>{},
      nowLocal: DateTime(2026, 9, 5, 8),
    );

    expect(atShiftStart.visibleCalls, isEmpty);
  });

  test('local hide removes call from visible but not active', () {
    final call = _call(
      callId: '7',
      revision: 7,
      finalizedAt: DateTime.utc(2026, 9, 4, 10),
      shift: SubstitutionShift(
        year: 2026,
        month: 9,
        day: 5,
        kind: SubstitutionShiftKind.day,
      ),
    );

    final resolution = resolver.resolve(
      calls: <SubstitutionConfirmedCall>[call],
      hiddenCallIds: <String>{'7'},
      nowLocal: DateTime(2026, 9, 4, 15),
    );

    expect(resolution.activeCalls, hasLength(1));

    expect(resolution.visibleCalls, isEmpty);

    expect(resolution.nextVisibleExpiryAtLocal, isNull);
  });

  test('sorts visible calls newest first', () {
    final older = _call(
      callId: '1',
      revision: 1,
      finalizedAt: DateTime.utc(2026, 9, 4, 10),
      shift: SubstitutionShift(
        year: 2026,
        month: 9,
        day: 5,
        kind: SubstitutionShiftKind.day,
      ),
    );

    final newer = _call(
      callId: '2',
      revision: 2,
      finalizedAt: DateTime.utc(2026, 9, 4, 11),
      shift: SubstitutionShift(
        year: 2026,
        month: 9,
        day: 5,
        kind: SubstitutionShiftKind.day,
      ),
    );

    final resolution = resolver.resolve(
      calls: <SubstitutionConfirmedCall>[older, newer],
      hiddenCallIds: <String>{},
      nowLocal: DateTime(2026, 9, 4, 15),
    );

    expect(resolution.visibleCalls.map((call) => call.callId), <String>[
      '2',
      '1',
    ]);
  });

  test('reports nearest visible expiry', () {
    final night = _call(
      callId: '1',
      revision: 1,
      finalizedAt: DateTime.utc(2026, 9, 4, 10),
      shift: SubstitutionShift(
        year: 2026,
        month: 9,
        day: 4,
        kind: SubstitutionShiftKind.night,
      ),
    );

    final nextDay = _call(
      callId: '2',
      revision: 2,
      finalizedAt: DateTime.utc(2026, 9, 4, 11),
      shift: SubstitutionShift(
        year: 2026,
        month: 9,
        day: 5,
        kind: SubstitutionShiftKind.day,
      ),
    );

    final resolution = resolver.resolve(
      calls: <SubstitutionConfirmedCall>[night, nextDay],
      hiddenCallIds: <String>{},
      nowLocal: DateTime(2026, 9, 4, 15),
    );

    expect(resolution.nextVisibleExpiryAtLocal, DateTime(2026, 9, 4, 20));
  });

  test('rejects UTC clock to avoid silent timezone mismatch', () {
    expect(
      () => resolver.resolve(
        calls: const <SubstitutionConfirmedCall>[],
        hiddenCallIds: <String>{},
        nowLocal: DateTime.utc(2026, 9, 4, 15),
      ),
      throwsArgumentError,
    );
  });
}

SubstitutionConfirmedCall _call({
  required String callId,
  required int revision,
  required DateTime finalizedAt,
  required SubstitutionShift shift,
}) {
  return SubstitutionConfirmedCall(
    callId: callId,
    userId: 'user-1',
    revision: revision,
    calledByUserId: 'brigadier-1',
    calledAt: finalizedAt.subtract(const Duration(seconds: 6)),
    finalizedAt: finalizedAt,
    shift: shift,
  );
}
