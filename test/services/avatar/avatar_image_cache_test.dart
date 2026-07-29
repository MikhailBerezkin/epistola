import 'dart:async';
import 'dart:typed_data';

import 'package:epistola/services/avatar/avatar_image_cache.dart';
import 'package:epistola/services/avatar/avatar_image_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deduplicates concurrent reads by storage path and version', () async {
    final completer = Completer<Uint8List?>();
    final source = _FakeAvatarImageSource((path, maximumBytes) {
      return completer.future;
    });
    final cache = AvatarImageCache(source: source);

    final first = cache.load(
      path: 'user_avatars/user-1/v4/thumb.jpg',
      version: 4,
      maxSizeBytes: 128 * 1024,
    );
    final second = cache.load(
      path: 'user_avatars/user-1/v4/thumb.jpg',
      version: 4,
      maxSizeBytes: 128 * 1024,
    );

    expect(source.callCount, 1);
    final bytes = Uint8List.fromList([1, 2, 3]);
    completer.complete(bytes);

    expect(await first, same(bytes));
    expect(await second, same(bytes));
  });

  test('different versions use different cache entries', () async {
    final source = _FakeAvatarImageSource(
      (path, maximumBytes) async => Uint8List.fromList([1]),
    );
    final cache = AvatarImageCache(source: source);

    await cache.load(path: 'avatar.jpg', version: 1, maxSizeBytes: 10);
    await cache.load(path: 'avatar.jpg', version: 2, maxSizeBytes: 10);
    await cache.load(path: 'avatar.jpg', version: 1, maxSizeBytes: 10);

    expect(source.callCount, 2);
  });

  test('rejects a source result above the requested size cap', () async {
    final source = _FakeAvatarImageSource(
      (path, maximumBytes) async => Uint8List(maximumBytes + 1),
    );
    final cache = AvatarImageCache(source: source);

    await expectLater(
      cache.load(path: 'avatar.jpg', version: 1, maxSizeBytes: 128),
      throwsA(
        isA<AvatarImageSizeLimitExceededException>()
            .having((error) => error.actualBytes, 'actualBytes', 129)
            .having((error) => error.maximumBytes, 'maximumBytes', 128),
      ),
    );
  });
}

typedef _Read = Future<Uint8List?> Function(String path, int maximumBytes);

final class _FakeAvatarImageSource implements AvatarImageSource {
  _FakeAvatarImageSource(this._read);

  final _Read _read;
  int callCount = 0;

  @override
  Future<Uint8List?> read({required String path, required int maxSizeBytes}) {
    callCount++;
    return _read(path, maxSizeBytes);
  }
}
