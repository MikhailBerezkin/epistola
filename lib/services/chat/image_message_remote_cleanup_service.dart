import 'image_message_remote_cleanup_plan.dart';

abstract interface class ImageMessageRemoteCleanupGateway {
  Future<void> deleteFile(String path);
}

final class ImageMessageRemoteCleanupFailure {
  const ImageMessageRemoteCleanupFailure({
    required this.path,
    required this.error,
    required this.stackTrace,
  });

  final String path;
  final Object error;
  final StackTrace stackTrace;
}

final class ImageMessageRemoteCleanupResult {
  ImageMessageRemoteCleanupResult({
    required List<String> attemptedPaths,
    required List<String> deletedPaths,
    required List<ImageMessageRemoteCleanupFailure> failures,
  }) : attemptedPaths = List.unmodifiable(attemptedPaths),
       deletedPaths = List.unmodifiable(deletedPaths),
       failures = List.unmodifiable(failures);

  final List<String> attemptedPaths;
  final List<String> deletedPaths;
  final List<ImageMessageRemoteCleanupFailure> failures;

  bool get isComplete {
    return failures.isEmpty && attemptedPaths.length == deletedPaths.length;
  }

  bool get hasFailures => failures.isNotEmpty;

  List<String> get failedPaths {
    return List.unmodifiable(failures.map((failure) => failure.path));
  }
}

final class ImageMessageRemoteCleanupService {
  const ImageMessageRemoteCleanupService({
    required ImageMessageRemoteCleanupGateway gateway,
  }) : this._(gateway);

  const ImageMessageRemoteCleanupService._(this._gateway);

  final ImageMessageRemoteCleanupGateway _gateway;

  Future<ImageMessageRemoteCleanupResult> cleanup(
    ImageMessageRemoteCleanupPlan plan,
  ) async {
    final attemptedPaths = <String>[];
    final deletedPaths = <String>[];
    final failures = <ImageMessageRemoteCleanupFailure>[];

    for (final path in plan.storagePaths) {
      attemptedPaths.add(path);

      try {
        await _gateway.deleteFile(path);
        deletedPaths.add(path);
      } catch (error, stackTrace) {
        failures.add(
          ImageMessageRemoteCleanupFailure(
            path: path,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }

    return ImageMessageRemoteCleanupResult(
      attemptedPaths: attemptedPaths,
      deletedPaths: deletedPaths,
      failures: failures,
    );
  }
}
