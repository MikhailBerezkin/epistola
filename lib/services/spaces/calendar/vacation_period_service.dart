import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/vacation_period.dart';
import 'vacation_period_firestore_gateway.dart';

final class VacationPeriodService {
  VacationPeriodService(this._gateway);

  factory VacationPeriodService.firebase({FirebaseFirestore? firestore}) {
    return VacationPeriodService(
      VacationPeriodFirestoreGateway.firebase(firestore: firestore),
    );
  }

  static const int maxSlots = 6;

  final VacationPeriodFirestoreGateway _gateway;

  Future<List<VacationPeriod>> loadForUser({required String userId}) {
    return _gateway.loadForUser(userId: userId);
  }

  Stream<List<VacationPeriod>> watchForUser({required String userId}) {
    return _gateway.watchForUser(userId: userId);
  }

  Stream<List<VacationPeriod>> watchAll() {
    return _gateway.watchAll();
  }

  Future<VacationPeriod> create({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final existingPeriods = await _gateway.loadForUser(userId: userId);

    final freeSlot = _findFirstFreeSlot(existingPeriods);

    if (freeSlot == null) {
      throw StateError('No free vacation slots.');
    }

    final period = VacationPeriod(
      userId: userId.trim(),
      slot: freeSlot,
      startDate: startDate,
      endDate: endDate,
    );

    if (!period.isValid) {
      throw ArgumentError.value(
        period,
        'period',
        'must be a valid vacation period',
      );
    }

    await _gateway.save(period);

    return period;
  }

  Future<VacationPeriod> update({
    required VacationPeriod currentPeriod,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final updatedPeriod = VacationPeriod(
      userId: currentPeriod.userId,
      slot: currentPeriod.slot,
      startDate: startDate,
      endDate: endDate,
    );

    if (!updatedPeriod.isValid) {
      throw ArgumentError.value(
        updatedPeriod,
        'period',
        'must be a valid vacation period',
      );
    }

    await _gateway.save(updatedPeriod);

    return updatedPeriod;
  }

  Future<void> delete({required VacationPeriod period}) {
    return _gateway.delete(userId: period.userId, slot: period.slot);
  }

  static int? _findFirstFreeSlot(List<VacationPeriod> periods) {
    final usedSlots = periods.map((period) => period.slot).toSet();

    for (var slot = 1; slot <= maxSlots; slot++) {
      if (!usedSlots.contains(slot)) {
        return slot;
      }
    }

    return null;
  }
}
