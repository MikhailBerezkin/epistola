import '../../domain/models/epistola_system_message.dart';

typedef EpistolaSystemMessagesLoader =
    Future<List<EpistolaSystemMessage>> Function({required String userId});

typedef EpistolaSystemMessagesWatcher =
    Stream<List<EpistolaSystemMessage>> Function({required String userId});

final class EpistolaSystemChatService {
  const EpistolaSystemChatService({
    required this.loader,
    required this.watcher,
  });

  final EpistolaSystemMessagesLoader loader;
  final EpistolaSystemMessagesWatcher watcher;

  Future<List<EpistolaSystemMessage>> load({required String userId}) {
    return loader(userId: _normalizeUserId(userId));
  }

  Stream<List<EpistolaSystemMessage>> watch({required String userId}) {
    return watcher(userId: _normalizeUserId(userId));
  }

  String _normalizeUserId(String userId) {
    final normalized = userId.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }

    return normalized;
  }
}
