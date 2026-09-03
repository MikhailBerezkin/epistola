import 'spaces_bar_message.dart';

final class SpacesBarBoard {
  const SpacesBarBoard._({required this.revision, required this.messages});

  static const int maxMessages = 3;

  final int revision;
  final List<SpacesBarMessage> messages;

  static SpacesBarBoard? tryCreate({
    required int revision,
    required List<SpacesBarMessage> messages,
  }) {
    if (revision < 0 || messages.length > maxMessages) {
      return null;
    }

    final messageIds = messages.map((message) => message.id).toSet();

    if (messageIds.length != messages.length) {
      return null;
    }

    return SpacesBarBoard._(
      revision: revision,
      messages: List.unmodifiable(messages),
    );
  }

  static SpacesBarBoard empty() {
    return SpacesBarBoard._(revision: 0, messages: const []);
  }

  List<SpacesBarMessage> activeMessagesAt(DateTime time) {
    return List.unmodifiable(
      messages.where((message) => message.isActiveAt(time)),
    );
  }

  bool hasCapacityAt(DateTime time) {
    return activeMessagesAt(time).length < maxMessages;
  }
}
