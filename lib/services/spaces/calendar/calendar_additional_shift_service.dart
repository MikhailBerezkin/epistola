import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/calendar_additional_shift_event.dart';
import '../substitution/substitution_confirmed_call_firestore_gateway.dart';
import 'calendar_additional_shift_projection.dart';

final class CalendarAdditionalShiftService {
  CalendarAdditionalShiftService(
    this._gateway, [
    this._projection = const CalendarAdditionalShiftProjection(),
  ]);

  factory CalendarAdditionalShiftService.firebase({
    FirebaseFirestore? firestore,
  }) {
    return CalendarAdditionalShiftService(
      SubstitutionConfirmedCallFirestoreGateway.firebase(firestore: firestore),
    );
  }

  final SubstitutionConfirmedCallFirestoreGateway _gateway;
  final CalendarAdditionalShiftProjection _projection;

  Future<List<CalendarAdditionalShiftEvent>> loadForUser({
    required String userId,
  }) async {
    final calls = await _gateway.loadForUser(userId: userId);

    return _projection.fromConfirmedCalls(calls);
  }

  Stream<List<CalendarAdditionalShiftEvent>> watchForUser({
    required String userId,
  }) {
    return _gateway
        .watchForUser(userId: userId)
        .map(_projection.fromConfirmedCalls);
  }
}
