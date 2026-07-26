import 'dart:typed_data';

import 'package:epistola/services/avatar/firebase_avatar_image_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the exact path with the caller-provided byte cap', () async {
    String? capturedPath;
    int? capturedMaximum;
    final source = FirebaseAvatarImageSource(
      readInvoker: ({required String path, required int maxSizeBytes}) async {
        capturedPath = path;
        capturedMaximum = maxSizeBytes;
        return Uint8List.fromList([1, 2, 3]);
      },
    );

    final result = await source.read(
      path: 'user_avatars/user-1/v7/full.jpg',
      maxSizeBytes: 512 * 1024,
    );

    expect(capturedPath, 'user_avatars/user-1/v7/full.jpg');
    expect(capturedMaximum, 512 * 1024);
    expect(result, [1, 2, 3]);
  });
}
