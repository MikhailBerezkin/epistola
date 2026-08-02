import 'package:epistola/services/chat/image_message_remote_cleanup_plan.dart';
import 'package:epistola/services/chat/image_message_remote_cleanup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageMessageRemoteCleanupService', () {
    test('deletes both planned objects', () async {
      final gateway = _FakeCleanupGateway();

      final service = ImageMessageRemoteCleanupService(gateway: gateway);

      final result = await service.cleanup(_plan());

      expect(gateway.attemptedPaths, orderedEquals(_plan().storagePaths));
      expect(result.attemptedPaths, orderedEquals(_plan().storagePaths));
      expect(result.deletedPaths, orderedEquals(_plan().storagePaths));
      expect(result.failures, isEmpty);
      expect(result.failedPaths, isEmpty);
      expect(result.hasFailures, isFalse);
      expect(result.isComplete, isTrue);
    });

    test('continues cleanup after the first deletion fails', () async {
      final plan = _plan();
      final failedPath = plan.thumbnailStoragePath;

      final gateway = _FakeCleanupGateway(failingPaths: {failedPath});

      final service = ImageMessageRemoteCleanupService(gateway: gateway);

      final result = await service.cleanup(plan);

      expect(gateway.attemptedPaths, orderedEquals(plan.storagePaths));
      expect(result.attemptedPaths, orderedEquals(plan.storagePaths));
      expect(result.deletedPaths, [plan.fullStoragePath]);
      expect(result.failures, hasLength(1));
      expect(result.failures.single.path, failedPath);
      expect(result.failures.single.error, isA<StateError>());
      expect(result.failedPaths, [failedPath]);
      expect(result.hasFailures, isTrue);
      expect(result.isComplete, isFalse);
    });

    test('collects failures for both objects', () async {
      final plan = _plan();

      final gateway = _FakeCleanupGateway(
        failingPaths: plan.storagePaths.toSet(),
      );

      final service = ImageMessageRemoteCleanupService(gateway: gateway);

      final result = await service.cleanup(plan);

      expect(gateway.attemptedPaths, orderedEquals(plan.storagePaths));
      expect(result.deletedPaths, isEmpty);
      expect(result.failures, hasLength(2));
      expect(result.failedPaths, orderedEquals(plan.storagePaths));
      expect(result.hasFailures, isTrue);
      expect(result.isComplete, isFalse);
    });

    test('returns immutable result collections', () async {
      final service = ImageMessageRemoteCleanupService(
        gateway: _FakeCleanupGateway(),
      );

      final result = await service.cleanup(_plan());

      expect(
        () => result.attemptedPaths.add('unexpected'),
        throwsUnsupportedError,
      );
      expect(() => result.deletedPaths.clear(), throwsUnsupportedError);
      expect(() => result.failures.clear(), throwsUnsupportedError);
    });
  });
}

ImageMessageRemoteCleanupPlan _plan() {
  final plan = ImageMessageRemoteCleanupPlan.tryCreate(
    chatId: 'chat-1',
    messageId: 'message-1',
    version: 3,
  );

  if (plan == null) {
    throw StateError('Test cleanup plan must be valid.');
  }

  return plan;
}

final class _FakeCleanupGateway implements ImageMessageRemoteCleanupGateway {
  _FakeCleanupGateway({Set<String> failingPaths = const {}})
    : failingPaths = Set.unmodifiable(failingPaths);

  final Set<String> failingPaths;
  final List<String> attemptedPaths = [];

  @override
  Future<void> deleteFile(String path) async {
    attemptedPaths.add(path);

    if (failingPaths.contains(path)) {
      throw StateError('Failed to delete $path');
    }
  }
}
