import 'dart:io';

import 'package:epistola/services/avatar/avatar_image_crop_gateway.dart';
import 'package:epistola/services/avatar/image_cropper_avatar_image_crop_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const imageCropperChannel = MethodChannel('plugins.hunghd.vn/image_cropper');
  late MethodCall? pluginCall;

  setUp(() {
    pluginCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imageCropperChannel, (call) async {
          pluginCall = call;
          return 'temporary/cropped-avatar.jpg';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imageCropperChannel, null);
  });

  group('ImageCropperAvatarImageCropGateway.cropSquare', () {
    test('maps the temporary cropped path without copying it', () async {
      final invoker = _FakeAvatarImageCropInvoker(
        resultPath: 'temporary/cropped-avatar.jpg',
      );
      final gateway = ImageCropperAvatarImageCropGateway(invoker: invoker.call);

      final result = await gateway.cropSquare('picker/source.png');

      expect(result?.path, 'temporary/cropped-avatar.jpg');
    });

    test('maps cropper cancellation to null', () async {
      final invoker = _FakeAvatarImageCropInvoker();
      final gateway = ImageCropperAvatarImageCropGateway(invoker: invoker.call);

      expect(await gateway.cropSquare('picker/source.jpg'), isNull);
    });

    test('passes the source path to a plugin-neutral invoker', () async {
      final invoker = _FakeAvatarImageCropInvoker();
      final gateway = ImageCropperAvatarImageCropGateway(invoker: invoker.call);

      await gateway.cropSquare('picker/source with spaces.png');

      expect(invoker.sourcePath, 'picker/source with spaces.png');
    });

    test(
      'passes exact intermediate output settings to image_cropper',
      () async {
        final gateway = ImageCropperAvatarImageCropGateway();
        final sourcePath = File('pubspec.yaml').absolute.path;

        await gateway.cropSquare(sourcePath);

        final arguments = _pluginArguments(pluginCall);
        expect(pluginCall?.method, 'cropImage');
        expect(arguments['source_path'], sourcePath);
        expect(arguments['ratio_x'], 1);
        expect(arguments['ratio_y'], 1);
        expect(arguments['compress_format'], 'jpg');
        expect(arguments['compress_quality'], 100);
        expect(arguments['max_width'], 1024);
        expect(arguments['max_height'], 1024);
      },
    );

    test('passes locked square rectangle settings for Android', () async {
      final gateway = ImageCropperAvatarImageCropGateway();

      await gateway.cropSquare(File('pubspec.yaml').absolute.path);

      final arguments = _pluginArguments(pluginCall);
      expect(arguments['android.toolbar_title'], 'Обрезать фото');
      expect(arguments['android.lock_aspect_ratio'], isTrue);
      expect(arguments['android.init_aspect_ratio'], 'square');
      expect(arguments['android.crop_style'], 'rectangle');
      expect(arguments['android.aspect_ratio_presets'], [
        {
          'name': 'square',
          'data': {'ratio_x': 1, 'ratio_y': 1},
        },
      ]);
    });

    test('passes locked square rectangle settings for iOS', () async {
      final gateway = ImageCropperAvatarImageCropGateway();

      await gateway.cropSquare(File('pubspec.yaml').absolute.path);

      final arguments = _pluginArguments(pluginCall);
      expect(arguments['ios.aspect_ratio_lock_enabled'], isTrue);
      expect(arguments['ios.reset_aspect_ratio_enabled'], isFalse);
      expect(arguments['ios.aspect_ratio_picker_button_hidden'], isTrue);
      expect(arguments['ios.aspect_ratio_presets'], [
        {
          'name': 'square',
          'data': {'ratio_x': 1, 'ratio_y': 1},
        },
      ]);
      expect(arguments['ios.title'], 'Обрезать фото');
      expect(arguments['ios.done_button_title'], 'Готово');
      expect(arguments['ios.cancel_button_title'], 'Отмена');
      expect(arguments['ios.crop_style'], 'rectangle');
    });

    test('rejects an empty source path before calling the invoker', () {
      final invoker = _FakeAvatarImageCropInvoker();
      final gateway = ImageCropperAvatarImageCropGateway(invoker: invoker.call);

      expect(
        () => gateway.cropSquare(''),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'sourcePath',
          ),
        ),
      );
      expect(invoker.callCount, 0);
    });

    test('maps a platform plugin error to a typed crop exception', () {
      final invoker = _FakeAvatarImageCropInvoker(
        error: PlatformException(
          code: 'cropper-failed',
          message: 'Native crop failed.',
        ),
      );
      final gateway = ImageCropperAvatarImageCropGateway(invoker: invoker.call);

      expect(
        () => gateway.cropSquare('picker/source.jpg'),
        throwsA(
          isA<AvatarImageCropException>()
              .having((error) => error.code, 'code', 'cropper-failed')
              .having(
                (error) => error.message,
                'message',
                'Native crop failed.',
              ),
        ),
      );
    });

    test('maps an unexpected plugin error to a stable typed failure', () {
      final invoker = _FakeAvatarImageCropInvoker(error: StateError('broken'));
      final gateway = ImageCropperAvatarImageCropGateway(invoker: invoker.call);

      expect(
        () => gateway.cropSquare('picker/source.jpg'),
        throwsA(
          isA<AvatarImageCropException>()
              .having((error) => error.code, 'code', 'crop_failed')
              .having(
                (error) => error.message,
                'message',
                'Failed to crop the avatar image.',
              ),
        ),
      );
    });
  });
}

Map<Object?, Object?> _pluginArguments(MethodCall? call) {
  return call!.arguments as Map<Object?, Object?>;
}

final class _FakeAvatarImageCropInvoker {
  _FakeAvatarImageCropInvoker({this.resultPath, this.error});

  final String? resultPath;
  final Object? error;
  String? sourcePath;
  int callCount = 0;

  Future<String?> call(String sourcePath) async {
    callCount++;
    this.sourcePath = sourcePath;

    final cropError = error;

    if (cropError != null) {
      throw cropError;
    }

    return resultPath;
  }
}
