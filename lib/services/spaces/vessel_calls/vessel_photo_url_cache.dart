import 'package:firebase_storage/firebase_storage.dart';

typedef VesselPhotoDownloadUrlResolver =
    Future<String> Function(String storagePath);

final class VesselPhotoUrlCache {
  VesselPhotoUrlCache({VesselPhotoDownloadUrlResolver? resolver})
    : _resolver = resolver ?? _firebaseResolver;

  final VesselPhotoDownloadUrlResolver _resolver;

  final Map<String, String> _resolvedUrls = <String, String>{};

  final Map<String, Future<String>> _pendingUrls = <String, Future<String>>{};

  String? read(String storagePath) {
    final normalizedPath = storagePath.trim();

    if (normalizedPath.isEmpty) {
      return null;
    }

    return _resolvedUrls[normalizedPath];
  }

  Future<String> resolve(String storagePath) {
    final normalizedPath = storagePath.trim();

    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(
        storagePath,
        'storagePath',
        'storagePath must not be empty.',
      );
    }

    final resolvedUrl = _resolvedUrls[normalizedPath];

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      return Future<String>.value(resolvedUrl);
    }

    final pendingUrl = _pendingUrls[normalizedPath];

    if (pendingUrl != null) {
      return pendingUrl;
    }

    late final Future<String> future;

    future = _resolver(normalizedPath).then(
      (url) {
        final normalizedUrl = url.trim();

        if (normalizedUrl.isEmpty) {
          throw StateError('Firebase Storage returned an empty download URL.');
        }

        _resolvedUrls[normalizedPath] = normalizedUrl;
        _pendingUrls.remove(normalizedPath);

        return normalizedUrl;
      },
      onError: (Object error, StackTrace stackTrace) {
        _pendingUrls.remove(normalizedPath);

        Error.throwWithStackTrace(error, stackTrace);
      },
    );

    _pendingUrls[normalizedPath] = future;

    return future;
  }

  Future<void> preload(
    Iterable<String?> storagePaths, {
    int maximumItems = 10,
  }) async {
    if (maximumItems <= 0) {
      return;
    }

    final uniquePaths = <String>{};

    for (final value in storagePaths) {
      final path = value?.trim() ?? '';

      if (path.isEmpty) {
        continue;
      }

      uniquePaths.add(path);

      if (uniquePaths.length >= maximumItems) {
        break;
      }
    }

    if (uniquePaths.isEmpty) {
      return;
    }

    await Future.wait<void>(
      uniquePaths.map((path) async {
        try {
          await resolve(path);
        } catch (_) {
          // Ошибка одного фото не должна задерживать
          // остальные фотографии выбранного дня.
        }
      }),
    );
  }

  void remove(String storagePath) {
    final normalizedPath = storagePath.trim();

    if (normalizedPath.isEmpty) {
      return;
    }

    _resolvedUrls.remove(normalizedPath);
    _pendingUrls.remove(normalizedPath);
  }

  void clear() {
    _resolvedUrls.clear();
    _pendingUrls.clear();
  }

  static Future<String> _firebaseResolver(String storagePath) {
    return FirebaseStorage.instance.ref(storagePath).getDownloadURL();
  }
}
