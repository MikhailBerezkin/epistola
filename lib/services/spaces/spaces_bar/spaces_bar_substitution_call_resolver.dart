import '../../../domain/models/substitution_confirmed_call.dart';
import '../../../domain/models/substitution_shift.dart';

final class SpacesBarSubstitutionCallResolution {
  const SpacesBarSubstitutionCallResolution({
    required this.activeCalls,
    required this.visibleCalls,
    required this.nextVisibleExpiryAtLocal,
  });

  /// Все ещё действующие вызовы.
  ///
  /// Local hide на этот список не влияет.
  final List<SubstitutionConfirmedCall> activeCalls;

  /// Действующие вызовы, которые пользователь
  /// не скрыл локально.
  final List<SubstitutionConfirmedCall> visibleCalls;

  /// Ближайший момент, когда один из видимых вызовов
  /// должен исчезнуть из SpacesBar.
  ///
  /// Нужен позже для локального Timer, потому что
  /// Firestore snapshot сам по себе не придёт ровно
  /// в 08:00 или 20:00.
  final DateTime? nextVisibleExpiryAtLocal;

  bool get hasVisibleCalls => visibleCalls.isNotEmpty;
}

final class SpacesBarSubstitutionCallResolver {
  const SpacesBarSubstitutionCallResolver();

  SpacesBarSubstitutionCallResolution resolve({
    required List<SubstitutionConfirmedCall> calls,
    required Set<String> hiddenCallIds,
    required DateTime nowLocal,
  }) {
    if (nowLocal.isUtc) {
      throw ArgumentError.value(
        nowLocal,
        'nowLocal',
        'must represent device-local time',
      );
    }

    final activeCalls = calls.where((call) {
      final shiftStartsAt = shiftStartsAtLocal(call.shift);

      return nowLocal.isBefore(shiftStartsAt);
    }).toList();

    activeCalls.sort(_compareNewestFirst);

    final visibleCalls = activeCalls
        .where((call) => !hiddenCallIds.contains(call.callId))
        .toList(growable: false);

    DateTime? nextVisibleExpiryAtLocal;

    for (final call in visibleCalls) {
      final expiry = shiftStartsAtLocal(call.shift);

      if (nextVisibleExpiryAtLocal == null ||
          expiry.isBefore(nextVisibleExpiryAtLocal)) {
        nextVisibleExpiryAtLocal = expiry;
      }
    }

    return SpacesBarSubstitutionCallResolution(
      activeCalls: List<SubstitutionConfirmedCall>.unmodifiable(activeCalls),
      visibleCalls: List<SubstitutionConfirmedCall>.unmodifiable(visibleCalls),
      nextVisibleExpiryAtLocal: nextVisibleExpiryAtLocal,
    );
  }

  DateTime shiftStartsAtLocal(SubstitutionShift shift) {
    return DateTime(shift.year, shift.month, shift.day, shift.startHour);
  }

  int _compareNewestFirst(
    SubstitutionConfirmedCall first,
    SubstitutionConfirmedCall second,
  ) {
    final finalizedComparison = second.finalizedAt.compareTo(first.finalizedAt);

    if (finalizedComparison != 0) {
      return finalizedComparison;
    }

    return second.revision.compareTo(first.revision);
  }
}
