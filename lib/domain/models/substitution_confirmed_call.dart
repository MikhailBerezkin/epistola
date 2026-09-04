import 'substitution_shift.dart';

final class SubstitutionConfirmedCall {
  const SubstitutionConfirmedCall({
    required this.callId,
    required this.userId,
    required this.revision,
    required this.calledByUserId,
    required this.calledAt,
    required this.finalizedAt,
    required this.shift,
  });

  final String callId;

  /// Пользователь, которого вызвали.
  final String userId;

  /// Глобальная revision операции "Списка".
  final int revision;

  /// Бригадир / owner, выполнивший вызов.
  final String calledByUserId;

  /// Момент первоначального вызова.
  final DateTime calledAt;

  /// Момент окончательного подтверждения после Undo-window.
  final DateTime finalizedAt;

  /// Конкретная смена, выбранная при вызове.
  final SubstitutionShift shift;
}
