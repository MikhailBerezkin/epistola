import 'dart:io';

import 'package:epistola/services/avatar/firebase_avatar_storage_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;
  late File image;

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'epistola_firebase_avatar_storage_gateway_test_',
    );
    image = File('${testDirectory.path}${Platform.pathSeparator}thumb.jpg');
    await image.writeAsBytes(List.filled(1234, 1));
  });

  tearDown(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test(
    'upload returns path metadata and never creates a download URL',
    () async {
      var uploadCallCount = 0;
      final timestamp = DateTime.utc(2026, 7, 26);
      final gateway = FirebaseAvatarStorageGateway(
        uploadInvoker:
            ({
              required file,
              required path,
              required type,
              required ownerType,
              required ownerId,
              required mimeType,
              required version,
            }) async {
              uploadCallCount++;
              expect(file, same(image));
              expect(path, 'user_avatars/user-1/v3/thumb.jpg');
              expect(mimeType, 'image/jpeg');
              return AvatarStorageUploadResult(
                sizeBytes: await file.length(),
                createdAt: timestamp,
                updatedAt: timestamp,
              );
            },
        deleteInvoker: (_) async {},
      );

      final asset = await gateway.uploadFile(
        file: image,
        path: 'user_avatars/user-1/v3/thumb.jpg',
        type: 'userAvatarThumbnail',
        ownerType: 'user',
        ownerId: 'user-1',
        mimeType: 'image/jpeg',
        version: 3,
      );

      expect(uploadCallCount, 1);
      expect(asset.path, 'user_avatars/user-1/v3/thumb.jpg');
      expect(asset.sizeBytes, 1234);
      expect(asset.updatedAt, timestamp);
      expect(asset.downloadUrl, isNull);
    },
  );

  test('avatar Firebase adapter contains no getDownloadURL call', () {
    final source = File(
      'lib/services/avatar/firebase_avatar_storage_gateway.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('getDownloadURL')));
  });
}
