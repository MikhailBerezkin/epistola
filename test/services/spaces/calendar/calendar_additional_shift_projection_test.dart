import 'package:epistola/domain/models/calendar_additional_shift_event.dart';
import 'package:epistola/domain/models/substitution_confirmed_call.dart';
import 'package:epistola/domain/models/substitution_shift.dart';
import 'package:epistola/services/spaces/calendar/calendar_additional_shift_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projection = CalendarAdditionalShiftProjection();

  group('CalendarAdditionalShiftProjection', () {
    test('projects day shift using local calendar time', () {
      final events = projection.fromConfirmedCalls([
        _confirmedCall(
          callId: '1',
          shift: SubstitutionShift(
            year: 2026,
            month: 9,
            day: 24,
            kind: SubstitutionShiftKind.day,
          ),
        ),
      ]);

      expect(events, hasLength(1));

      final event = events.single;

      expect(event.sourceCallId, '1');
      expect(event.date, DateTime(2026, 9, 24));
      expect(event.kind, SubstitutionShiftKind.day);
      expect(event.startAt, DateTime(2026, 9, 24, 8));
      expect(event.endAt, DateTime(2026, 9, 24, 20));
    });

    test('projects night shift ending on next calendar day', () {
      final events = projection.fromConfirmedCalls([
        _confirmedCall(
          callId: '2',
          shift: SubstitutionShift(
            year: 2026,
            month: 9,
            day: 24,
            kind: SubstitutionShiftKind.night,
          ),
        ),
      ]);

      final event = events.single;

      expect(event.startAt, DateTime(2026, 9, 24, 20));
      expect(event.endAt, DateTime(2026, 9, 25, 8));
    });

    test('derives upcoming and occurred from start time', () {
      final event = projection.fromConfirmedCalls([
        _confirmedCall(
          callId: '3',
          shift: SubstitutionShift(
            year: 2026,
            month: 9,
            day: 24,
            kind: SubstitutionShiftKind.day,
          ),
        ),
      ]).single;

      expect(
        event.stateAt(DateTime(2026, 9, 24, 7, 59)),
        CalendarAdditionalShiftState.upcoming,
      );

      expect(
        event.stateAt(DateTime(2026, 9, 24, 8)),
        CalendarAdditionalShiftState.occurred,
      );

      expect(
        event.stateAt(DateTime(2026, 9, 24, 12)),
        CalendarAdditionalShiftState.occurred,
      );
    });

    test('matches the shift start calendar day regardless of time', () {
      final event = projection.fromConfirmedCalls([
        _confirmedCall(
          callId: '4',
          shift: SubstitutionShift(
            year: 2026,
            month: 10,
            day: 3,
            kind: SubstitutionShiftKind.night,
          ),
        ),
      ]).single;

      expect(event.occursOn(DateTime(2026, 10, 3)), isTrue);
      expect(event.occursOn(DateTime(2026, 10, 3, 23, 59)), isTrue);
      expect(event.occursOn(DateTime(2026, 10, 4)), isFalse);
    });

    test('deduplicates events by stable source call id', () {
      final call = _confirmedCall(
        callId: '5',
        shift: SubstitutionShift(
          year: 2026,
          month: 9,
          day: 26,
          kind: SubstitutionShiftKind.day,
        ),
      );

      final events = projection.fromConfirmedCalls([call, call]);

      expect(events, hasLength(1));
      expect(events.single.sourceCallId, '5');
    });

    test('sorts projected events by shift start time', () {
      final events = projection.fromConfirmedCalls([
        _confirmedCall(
          callId: '8',
          shift: SubstitutionShift(
            year: 2026,
            month: 9,
            day: 27,
            kind: SubstitutionShiftKind.night,
          ),
        ),
        _confirmedCall(
          callId: '6',
          shift: SubstitutionShift(
            year: 2026,
            month: 9,
            day: 26,
            kind: SubstitutionShiftKind.day,
          ),
        ),
        _confirmedCall(
          callId: '7',
          shift: SubstitutionShift(
            year: 2026,
            month: 9,
            day: 27,
            kind: SubstitutionShiftKind.day,
          ),
        ),
      ]);

      expect(events.map((event) => event.sourceCallId), <String>[
        '6',
        '7',
        '8',
      ]);
    });
  });
}

SubstitutionConfirmedCall _confirmedCall({
  required String callId,
  required SubstitutionShift shift,
}) {
  final revision = int.parse(callId);

  return SubstitutionConfirmedCall(
    callId: callId,
    userId: 'user-1',
    revision: revision,
    calledByUserId: 'brigadier-1',
    calledAt: DateTime.utc(2026, 9, 23, 12),
    finalizedAt: DateTime.utc(2026, 9, 23, 12, 0, 3),
    shift: shift,
  );
}
