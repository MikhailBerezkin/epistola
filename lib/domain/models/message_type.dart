enum MessageType {
  text('text'),
  image('image');

  const MessageType(this.storageValue);

  final String storageValue;

  /// Старые текстовые сообщения не содержат поле messageType.
  /// Поэтому отсутствие значения читается как legacy text message.
  static MessageType? tryParseStorageValue(Object? value) {
    if (value == null) {
      return MessageType.text;
    }

    if (value is! String) {
      return null;
    }

    return switch (value) {
      'text' => MessageType.text,
      'image' => MessageType.image,
      _ => null,
    };
  }
}
