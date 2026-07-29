import 'package:epistola/services/avatar/avatar_image_picker_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_picker_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarImagePickerService image selection', () {
    test('returns an image selected from the gallery', () async {
      const image = AvatarPickedImage(path: 'gallery/source.jpg');
      final gateway = _FakeAvatarImagePickerGateway(pickResult: image);
      final service = AvatarImagePickerService(gateway: gateway);

      final result = await service.pickFromGallery();

      expect(result, same(image));
      expect(gateway.lastSource, AvatarImagePickSource.gallery);
    });

    test('returns an image captured with the camera', () async {
      const image = AvatarPickedImage(path: 'camera/source.jpg');
      final gateway = _FakeAvatarImagePickerGateway(pickResult: image);
      final service = AvatarImagePickerService(gateway: gateway);

      final result = await service.takeWithCamera();

      expect(result, same(image));
      expect(gateway.lastSource, AvatarImagePickSource.camera);
    });

    test('treats gallery cancellation as a normal result', () async {
      final gateway = _FakeAvatarImagePickerGateway();
      final service = AvatarImagePickerService(gateway: gateway);

      expect(await service.pickFromGallery(), isNull);
    });

    test('treats camera cancellation as a normal result', () async {
      final gateway = _FakeAvatarImagePickerGateway();
      final service = AvatarImagePickerService(gateway: gateway);

      expect(await service.takeWithCamera(), isNull);
    });
  });

  group('AvatarImagePickerService lost data recovery', () {
    test('returns null when there are no lost images', () async {
      final gateway = _FakeAvatarImagePickerGateway();
      final service = AvatarImagePickerService(gateway: gateway);

      expect(await service.recoverLostImage(), isNull);
    });

    test('returns a recovered lost image', () async {
      const image = AvatarPickedImage(path: 'recovered/source.jpg');
      final gateway = _FakeAvatarImagePickerGateway(lostImages: [image]);
      final service = AvatarImagePickerService(gateway: gateway);

      expect(await service.recoverLostImage(), same(image));
    });

    test('keeps the first image when multiple files are recovered', () async {
      const first = AvatarPickedImage(path: 'recovered/first.jpg');
      const second = AvatarPickedImage(path: 'recovered/second.jpg');
      final gateway = _FakeAvatarImagePickerGateway(
        lostImages: [first, second],
      );
      final service = AvatarImagePickerService(gateway: gateway);

      expect(await service.recoverLostImage(), same(first));
    });

    test('keeps a lost data recovery error separate from cancellation', () {
      const error = AvatarLostDataRecoveryException(
        code: 'lost-data-error',
        message: 'Could not recover the image.',
      );
      final gateway = _FakeAvatarImagePickerGateway(lostError: error);
      final service = AvatarImagePickerService(gateway: gateway);

      expect(service.recoverLostImage, throwsA(same(error)));
    });
  });
}

final class _FakeAvatarImagePickerGateway implements AvatarImagePickerGateway {
  _FakeAvatarImagePickerGateway({
    this.pickResult,
    this.lostImages = const [],
    this.lostError,
  });

  final AvatarPickedImage? pickResult;
  final List<AvatarPickedImage> lostImages;
  final Object? lostError;
  AvatarImagePickSource? lastSource;

  @override
  Future<AvatarPickedImage?> pickImage(AvatarImagePickSource source) async {
    lastSource = source;
    return pickResult;
  }

  @override
  Future<List<AvatarPickedImage>> retrieveLostImages() async {
    final error = lostError;

    if (error != null) {
      throw error;
    }

    return lostImages;
  }
}
