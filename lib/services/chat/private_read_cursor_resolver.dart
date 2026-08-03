import '../../domain/models/private_read_cursor.dart';

typedef PrivateReadCursorCandidate = ({
  String messageId,
  DateTime? messageCreatedAt,
  bool isVisible,
});

final class PrivateReadCursorResolver {
  const PrivateReadCursorResolver._();

  static PrivateReadCursor? fromChronologicalCandidates(
    Iterable<PrivateReadCursorCandidate> candidates,
  ) {
    PrivateReadCursor? latestCursor;

    for (final candidate in candidates) {
      if (!candidate.isVisible) {
        continue;
      }

      final cursor = PrivateReadCursor.tryCreate(
        messageId: candidate.messageId,
        messageCreatedAt: candidate.messageCreatedAt,
      );

      if (cursor == null) {
        continue;
      }

      latestCursor = cursor;
    }

    return latestCursor;
  }
}
