import 'package:epistola/services/avatar/avatar_image_compressor_gateway.dart';
import 'package:epistola/services/avatar/avatar_image_pipeline_config.dart';
import 'package:epistola/services/avatar/flutter_image_compress_avatar_image_compressor_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = AvatarImageCompressionRequest(
    sourcePath: 'cropped/source.jpg',
    targetPath: 'temporary/output.jpg',
    format: AvatarImageFormat.jpeg,
    width: 128,
    height: 128,
    quality: 75,
    keepExif: false,
    autoCorrectionAngle: true,
    rotate: 0,
  );

  test('maps a plugin-neutral invoker output', () async {
    AvatarImageCompressionRequest? receivedRequest;
    final gateway = FlutterImageCompressAvatarImageCompressorGateway(
      invoker: (value) async {
        receivedRequest = value;
        return value.targetPath;
      },
    );

    final result = await gateway.compress(request);

    expect(receivedRequest, same(request));
    expect(result?.path, request.targetPath);
  });

  test('maps a null plugin output without inventing a file', () async {
    final gateway = FlutterImageCompressAvatarImageCompressorGateway(
      invoker: (_) async => null,
    );

    expect(await gateway.compress(request), isNull);
  });

  test('maps a platform failure to a typed compressor exception', () {
    final gateway = FlutterImageCompressAvatarImageCompressorGateway(
      invoker: (_) async {
        throw PlatformException(
          code: 'native-compression-failed',
          message: 'Native compression failed.',
        );
      },
    );

    expect(
      () => gateway.compress(request),
      throwsA(
        isA<AvatarImageCompressorException>()
            .having((error) => error.code, 'code', 'native-compression-failed')
            .having(
              (error) => error.message,
              'message',
              'Native compression failed.',
            ),
      ),
    );
  });

  test('maps an unexpected failure to a stable typed exception', () {
    final gateway = FlutterImageCompressAvatarImageCompressorGateway(
      invoker: (_) async => throw StateError('broken'),
    );

    expect(
      () => gateway.compress(request),
      throwsA(
        isA<AvatarImageCompressorException>().having(
          (error) => error.code,
          'code',
          'compression_failed',
        ),
      ),
    );
  });
}
