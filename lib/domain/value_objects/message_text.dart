class MessageText {
  static const int maxLength = 4096;

  final String value;

  const MessageText._(this.value);

  static String normalize(String text) {
    return text.trim();
  }

  static bool isValid(String text) {
    final normalized = normalize(text);

    return normalized.isNotEmpty && normalized.length <= maxLength;
  }

  static MessageText? tryParse(String text) {
    final normalized = normalize(text);

    if (!isValid(normalized)) {
      return null;
    }

    return MessageText._(normalized);
  }
}
