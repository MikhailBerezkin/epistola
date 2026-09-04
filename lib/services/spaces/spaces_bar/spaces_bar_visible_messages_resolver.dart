import 'package:epistola/domain/models/spaces_bar_board.dart';
import 'package:epistola/domain/models/spaces_bar_message.dart';

final class SpacesBarVisibleMessagesResolver {
  const SpacesBarVisibleMessagesResolver();

  List<SpacesBarMessage> resolve({
    required SpacesBarBoard board,
    required Set<String> hiddenMessageIds,
    required DateTime now,
  }) {
    final visibleMessages = board
        .activeMessagesAt(now)
        .where((message) => !hiddenMessageIds.contains(message.id))
        .toList(growable: false);

    visibleMessages.sort(_compareMessages);

    return List.unmodifiable(visibleMessages);
  }

  int _compareMessages(SpacesBarMessage first, SpacesBarMessage second) {
    final createdAtComparison = second.createdAt.compareTo(first.createdAt);

    if (createdAtComparison != 0) {
      return createdAtComparison;
    }

    return _compareMessageIdsDescending(first.id, second.id);
  }

  int _compareMessageIdsDescending(String firstId, String secondId) {
    final firstRevision = int.tryParse(firstId);
    final secondRevision = int.tryParse(secondId);

    if (firstRevision != null && secondRevision != null) {
      return secondRevision.compareTo(firstRevision);
    }

    return secondId.compareTo(firstId);
  }
}
