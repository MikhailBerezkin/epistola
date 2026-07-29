import 'package:epistola/services/avatar/avatar_image_crop_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_crop_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarImageCropService.crop', () {
    test('returns a successful square crop result', () async {
      const image = AvatarCroppedImage(path: 'cache/cropped.jpg');
      final gateway = _FakeAvatarImageCropGateway(result: image);
      final service = AvatarImageCropService(gateway: gateway);

      final result = await service.crop('picker/source.png');

      expect(result, same(image));
    });

    test('treats user cancellation as a normal null result', () async {
      final gateway = _FakeAvatarImageCropGateway();
      final service = AvatarImageCropService(gateway: gateway);

      expect(await service.crop('picker/source.jpg'), isNull);
    });

    test('passes the source path to the gateway unchanged', () async {
      final gateway = _FakeAvatarImageCropGateway();
      final service = AvatarImageCropService(gateway: gateway);

      await service.crop('picker/source with spaces.jpg');

      expect(gateway.lastSourcePath, 'picker/source with spaces.jpg');
    });

    test('rejects an empty source path before calling the gateway', () {
      final gateway = _FakeAvatarImageCropGateway();
      final service = AvatarImageCropService(gateway: gateway);

      expect(
        () => service.crop('   '),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'sourcePath',
          ),
        ),
      );
      expect(gateway.callCount, 0);
    });

    test('keeps a typed crop failure separate from cancellation', () {
      const error = AvatarImageCropException(
        code: 'crop-error',
        message: 'Could not crop the image.',
      );
      final gateway = _FakeAvatarImageCropGateway(error: error);
      final service = AvatarImageCropService(gateway: gateway);

      expect(() => service.crop('picker/source.jpg'), throwsA(same(error)));
    });
  });
}

final class _FakeAvatarImageCropGateway implements AvatarImageCropGateway {
  _FakeAvatarImageCropGateway({this.result, this.error});

  final AvatarCroppedImage? result;
  final Object? error;
  String? lastSourcePath;
  int callCount = 0;

  @override
  Future<AvatarCroppedImage?> cropSquare(String sourcePath) async {
    callCount++;
    lastSourcePath = sourcePath;

    final cropError = error;

    if (cropError != null) {
      throw cropError;
    }

    return result;
  }
}
