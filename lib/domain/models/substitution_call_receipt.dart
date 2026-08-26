final class SubstitutionCallReceipt {
  const SubstitutionCallReceipt({required this.userId, required this.revision});

  final String userId;

  /// Номер конкретного подтверждённого вызова.
  ///
  /// Undo разрешён только пока этот revision остаётся
  /// последним вызовом в пространстве.
  final int revision;
}
