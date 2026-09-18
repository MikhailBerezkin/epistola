class VacationPeriod {
  const VacationPeriod({
    required this.userId,
    required this.slot,
    required this.startDate,
    required this.endDate,
  });

  final String userId;
  final int slot;
  final DateTime startDate;
  final DateTime endDate;

  bool get isValid {
    return userId.trim().isNotEmpty &&
        slot >= 1 &&
        slot <= 6 &&
        !endDateOnly.isBefore(startDateOnly);
  }

  DateTime get startDateOnly {
    return DateTime.utc(startDate.year, startDate.month, startDate.day);
  }

  DateTime get endDateOnly {
    return DateTime.utc(endDate.year, endDate.month, endDate.day);
  }

  String get documentId => '${userId.trim()}__$slot';

  bool contains(DateTime date) {
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);

    return !normalizedDate.isBefore(startDateOnly) &&
        !normalizedDate.isAfter(endDateOnly);
  }
}
