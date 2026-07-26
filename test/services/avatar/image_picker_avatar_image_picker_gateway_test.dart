import 'package:epistola/services/avatar/avatar_image_picker_gateway.dart';
import 'package:epistola/services/avatar/image_picker_avatar_image_picker_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  group('ImagePickerAvatarImagePickerGateway.pickImage', () {
    test('maps gallery source without preliminary compression', () async {
      final client = _FakeImagePickerClient(
        pickResult: XFile('gallery/source.jpg'),
      );
      final gateway = ImagePickerAvatarImagePickerGateway(client: client);

      final result = await gateway.pickImage(AvatarImagePickSource.gallery);

      expect(result?.path, 'gallery/source.jpg');
      expect(client.lastSource, ImageSource.gallery);
    });

    test('maps camera source', () async {
      final client = _FakeImagePickerClient(
        pickResult: XFile('camera/source.jpg'),
      );
      final gateway = ImagePickerAvatarImagePickerGateway(client: client);

      final result = await gateway.pickImage(AvatarImagePickSource.camera);

      expect(result?.path, 'camera/source.jpg');
      expect(client.lastSource, ImageSource.camera);
    });

    test('maps picker cancellation to null', () async {
      final client = _FakeImagePickerClient();
      final gateway = ImagePickerAvatarImagePickerGateway(client: client);

      expect(await gateway.pickImage(AvatarImagePickSource.gallery), isNull);
    });
  });

  group('ImagePickerAvatarImagePickerGateway.retrieveLostImages', () {
    test('returns no images for an empty lost data response', () async {
      final client = _FakeImagePickerClient();
      final gateway = ImagePickerAvatarImagePickerGateway(client: client);

      expect(await gateway.retrieveLostImages(), isEmpty);
    });

    test('maps a recovered lost image', () async {
      final client = _FakeImagePickerClient(
        lostData: LostDataResponse(
          files: [XFile('recovered/source.jpg')],
          type: RetrieveType.image,
        ),
      );
      final gateway = ImagePickerAvatarImagePickerGateway(client: client);

      final images = await gateway.retrieveLostImages();

      expect(images, hasLength(1));
      expect(images.single.path, 'recovered/source.jpg');
    });

    test('maps a lost data error to a typed exception', () {
      final client = _FakeImagePickerClient(
        lostData: LostDataResponse(
          exception: PlatformException(
            code: 'lost-data-error',
            message: 'Could not recover the image.',
          ),
          type: RetrieveType.image,
        ),
      );
      final gateway = ImagePickerAvatarImagePickerGateway(client: client);

      expect(
        gateway.retrieveLostImages,
        throwsA(
          isA<AvatarLostDataRecoveryException>()
              .having((error) => error.code, 'code', 'lost-data-error')
              .having(
                (error) => error.message,
                'message',
                'Could not recover the image.',
              ),
        ),
      );
    });

    test(
      'preserves recovered file order for deterministic selection',
      () async {
        final client = _FakeImagePickerClient(
          lostData: LostDataResponse(
            files: [
              XFile('recovered/first.jpg'),
              XFile('recovered/second.jpg'),
            ],
            type: RetrieveType.image,
          ),
        );
        final gateway = ImagePickerAvatarImagePickerGateway(client: client);

        final images = await gateway.retrieveLostImages();

        expect(images.map((image) => image.path), [
          'recovered/first.jpg',
          'recovered/second.jpg',
        ]);
      },
    );
  });
}

final class _FakeImagePickerClient implements ImagePickerClient {
  _FakeImagePickerClient({this.pickResult, LostDataResponse? lostData})
    : lostData = lostData ?? LostDataResponse.empty();

  final XFile? pickResult;
  final LostDataResponse lostData;
  ImageSource? lastSource;

  @override
  Future<XFile?> pickImage({required ImageSource source}) async {
    lastSource = source;
    return pickResult;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    return lostData;
  }
}
