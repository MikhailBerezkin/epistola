class ChatDateFormatter {
  const ChatDateFormatter._();

  static const List<String> _monthNames = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  static String format(DateTime value, {DateTime? now}) {
    final localValue = value.toLocal();
    final localNow = (now ?? DateTime.now()).toLocal();

    if (isSameDay(localValue, localNow)) {
      return 'Сегодня';
    }

    final yesterday = DateTime(localNow.year, localNow.month, localNow.day - 1);

    if (isSameDay(localValue, yesterday)) {
      return 'Вчера';
    }

    final monthName = _monthNames[localValue.month - 1];
    final date = '${localValue.day} $monthName';

    if (localValue.year == localNow.year) {
      return date;
    }

    return '$date ${localValue.year}';
  }

  static bool isSameDay(DateTime first, DateTime second) {
    final localFirst = first.toLocal();
    final localSecond = second.toLocal();

    return localFirst.year == localSecond.year &&
        localFirst.month == localSecond.month &&
        localFirst.day == localSecond.day;
  }

  static bool startsNewDay({required DateTime current, DateTime? previous}) {
    if (previous == null) {
      return true;
    }

    return !isSameDay(current, previous);
  }
}
