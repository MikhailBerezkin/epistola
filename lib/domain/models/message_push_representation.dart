import 'message_type.dart';

final class MessagePushRepresentation {
  const MessagePushRepresentation({required this.type, required this.text});

  final MessageType type;
  final String text;
}
