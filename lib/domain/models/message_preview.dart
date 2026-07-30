import 'message_type.dart';

final class MessagePreview {
  const MessagePreview({required this.type, required this.text});

  final MessageType type;
  final String text;
}
