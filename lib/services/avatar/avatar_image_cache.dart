import 'dart:collection';
import 'dart:typed_data';

import 'avatar_image_loader.dart';

final class AvatarImageCache implements AvatarImageLoader {
  factory AvatarImageCache({
    required AvatarImageSource source,
    int maximumEntries = 64,
  }) {
    if (maximumEntries <= 0) {
      throw ArgumentError.value(
        maximumEntries,
        'maximumEntries',
        'Maximum entries must be positive.',
      );
    }
    return AvatarImageCache._(source, maximumEntries);
  }

  AvatarImageCache._(this._source, this.maximumEntries);

  final AvatarImageSource _source;
  final int maximumEntries;
  final LinkedHashMap<String, Uint8List> _memory = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _inFlight = {};

  @override
  Future<Uint8List?> load({
    required String path,
    required int version,
    required int maxSizeBytes,
  }) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Path must not be empty.');
    }
    if (version <= 0) {
      throw ArgumentError.value(
        version,
        'version',
        'Version must be positive.',
      );
    }
    if (maxSizeBytes <= 0) {
      throw ArgumentError.value(
        maxSizeBytes,
        'maxSizeBytes',
        'Maximum size must be positive.',
      );
    }

    final key = '$normalizedPath@$version';
    final cached = _memory.remove(key);
    if (cached != null) {
      _memory[key] = cached;
      return Future.value(_enforceLimit(cached, maxSizeBytes));
    }

    final existing = _inFlight[key];
    if (existing != null) {
      return existing.then(
        (bytes) => bytes == null ? null : _enforceLimit(bytes, maxSizeBytes),
      );
    }

    final pending = _readAndCache(
      key: key,
      path: normalizedPath,
      maxSizeBytes: maxSizeBytes,
    );
    _inFlight[key] = pending;
    return pending;
  }

  Future<Uint8List?> _readAndCache({
    required String key,
    required String path,
    required int maxSizeBytes,
  }) async {
    try {
      final bytes = await _source.read(path: path, maxSizeBytes: maxSizeBytes);
      if (bytes == null) {
        return null;
      }

      final validated = _enforceLimit(bytes, maxSizeBytes);
      _memory[key] = validated;
      while (_memory.length > maximumEntries) {
        _memory.remove(_memory.keys.first);
      }
      return validated;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Uint8List _enforceLimit(Uint8List bytes, int maximumBytes) {
    if (bytes.lengthInBytes > maximumBytes) {
      throw AvatarImageSizeLimitExceededException(
        actualBytes: bytes.lengthInBytes,
        maximumBytes: maximumBytes,
      );
    }
    return bytes;
  }
}
