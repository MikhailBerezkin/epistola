import 'substitution_shift.dart';

final class SubstitutionPendingCall {
  const SubstitutionPendingCall({
    required this.callId,
    required this.userId,
    required this.revision,
    required this.calledByUserId,
    required this.calledAt,
    required this.shift,
  });

  static const Duration undoWindow = Duration(seconds: 6);

  final String callId;
  final String userId;
  final int revision;
  final String calledByUserId;
  final DateTime calledAt;

  /// Конкретная рабочая смена, выбранная бригадиром при вызове.
  ///
  /// Именно она определяет месяц и год будущей статистики.
  final SubstitutionShift shift;

  DateTime get undoDeadline => calledAt.add(undoWindow);

  bool isUndoWindowOpenAt(DateTime time) {
    return time.isBefore(undoDeadline);
  }

  bool canFinalizeAt(DateTime time) {
    return !time.isBefore(undoDeadline);
  }
}
