final class VacationDateRange {
  const VacationDateRange({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime endDate;
}

final class VacationDateParser {
  const VacationDateParser();

  static const Map<String, int> _monthNumbers = {
    'январь': 1,
    'января': 1,
    'февраль': 2,
    'февраля': 2,
    'март': 3,
    'марта': 3,
    'апрель': 4,
    'апреля': 4,
    'май': 5,
    'мая': 5,
    'июнь': 6,
    'июня': 6,
    'июль': 7,
    'июля': 7,
    'август': 8,
    'августа': 8,
    'сентябрь': 9,
    'сентября': 9,
    'октябрь': 10,
    'октября': 10,
    'ноябрь': 11,
    'ноября': 11,
    'декабрь': 12,
    'декабря': 12,
  };

  DateTime? parseDate(String input, {required int defaultYear}) {
    return _parseDetailed(input, defaultYear: defaultYear)?.date;
  }

  VacationDateRange? parseRange({
    required String startText,
    required String endText,
    required int calendarYear,
  }) {
    if (!_isValidYear(calendarYear)) {
      return null;
    }

    final start = _parseDetailed(startText, defaultYear: calendarYear);

    if (start == null) {
      return null;
    }

    final end = _parseDetailed(endText, defaultYear: start.date.year);

    if (end == null) {
      return null;
    }

    var resolvedEndDate = end.date;

    if (!end.hasExplicitYear && resolvedEndDate.isBefore(start.date)) {
      final nextYear = start.date.year + 1;

      if (!_isValidYear(nextYear)) {
        return null;
      }

      final nextYearDate = _createValidDate(
        year: nextYear,
        month: end.date.month,
        day: end.date.day,
      );

      if (nextYearDate == null) {
        return null;
      }

      resolvedEndDate = nextYearDate;
    }

    if (resolvedEndDate.isBefore(start.date)) {
      return null;
    }

    return VacationDateRange(startDate: start.date, endDate: resolvedEndDate);
  }

  _ParsedVacationDate? _parseDetailed(
    String input, {
    required int defaultYear,
  }) {
    if (!_isValidYear(defaultYear)) {
      return null;
    }

    final normalized = input.trim().toLowerCase().replaceAll('/', '.');

    if (normalized.isEmpty) {
      return null;
    }

    final numericMatch = RegExp(
      r'^(\d{1,2})\.(\d{1,2})(?:\.(\d{4}))?\.?$',
    ).firstMatch(normalized);

    if (numericMatch != null) {
      final day = int.tryParse(numericMatch.group(1)!);
      final month = int.tryParse(numericMatch.group(2)!);
      final yearText = numericMatch.group(3);
      final year = yearText == null ? defaultYear : int.tryParse(yearText);

      if (day == null || month == null || year == null || !_isValidYear(year)) {
        return null;
      }

      final date = _createValidDate(year: year, month: month, day: day);

      if (date == null) {
        return null;
      }

      return _ParsedVacationDate(date: date, hasExplicitYear: yearText != null);
    }

    final textMatch = RegExp(
      r'^(\d{1,2})\s+([а-яё]+)(?:\s+(\d{4}))?$',
    ).firstMatch(normalized);

    if (textMatch == null) {
      return null;
    }

    final day = int.tryParse(textMatch.group(1)!);
    final month = _monthNumbers[textMatch.group(2)!];
    final yearText = textMatch.group(3);
    final year = yearText == null ? defaultYear : int.tryParse(yearText);

    if (day == null || month == null || year == null || !_isValidYear(year)) {
      return null;
    }

    final date = _createValidDate(year: year, month: month, day: day);

    if (date == null) {
      return null;
    }

    return _ParsedVacationDate(date: date, hasExplicitYear: yearText != null);
  }

  DateTime? _createValidDate({
    required int year,
    required int month,
    required int day,
  }) {
    if (!_isValidYear(year) || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime.utc(year, month, day);

    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  bool _isValidYear(int year) {
    return year >= 1 && year <= 9999;
  }
}

final class _ParsedVacationDate {
  const _ParsedVacationDate({
    required this.date,
    required this.hasExplicitYear,
  });

  final DateTime date;
  final bool hasExplicitYear;
}
