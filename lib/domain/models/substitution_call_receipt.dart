final class SubstitutionCallReceipt {
  const SubstitutionCallReceipt({required this.userId, required this.revision});

  final String userId;

  /// Глобальный номер конкретной операции вызова.
  ///
  /// Используется как identity вызова для Undo и последующей
  /// exactly-once финализации статистики.
  final int revision;

  /// Стабильный идентификатор pending-call.
  ///
  /// Revision уже является уникальным внутри пространства Подсменки,
  /// поэтому отдельный случайный UUID не требуется.
  String get callId => revision.toString();
}
