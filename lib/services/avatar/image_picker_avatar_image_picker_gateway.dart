import 'package:image_picker/image_picker.dart';

import 'avatar_image_picker_gateway.dart';

abstract interface class ImagePickerClient {
  Future<XFile?> pickImage({required ImageSource source});

  Future<LostDataResponse> retrieveLostData();
}

final class _PluginImagePickerClient implements ImagePickerClient {
  _PluginImagePickerClient({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickImage({required ImageSource source}) {
    return _picker.pickImage(source: source);
  }

  @override
  Future<LostDataResponse> retrieveLostData() {
    return _picker.retrieveLostData();
  }
}

final class ImagePickerAvatarImagePickerGateway
    implements AvatarImagePickerGateway {
  ImagePickerAvatarImagePickerGateway({ImagePickerClient? client})
    : _client = client ?? _PluginImagePickerClient();

  final ImagePickerClient _client;

  @override
  Future<AvatarPickedImage?> pickImage(AvatarImagePickSource source) async {
    final file = await _client.pickImage(source: _mapSource(source));
    return file == null ? null : AvatarPickedImage(path: file.path);
  }

  @override
  Future<List<AvatarPickedImage>> retrieveLostImages() async {
    final response = await _client.retrieveLostData();

    if (response.isEmpty) {
      return const [];
    }

    final exception = response.exception;

    if (exception != null) {
      throw AvatarLostDataRecoveryException(
        code: exception.code,
        message: exception.message,
      );
    }

    if (response.type != null && response.type != RetrieveType.image) {
      throw const AvatarLostDataRecoveryException(
        code: 'unexpected_recovered_type',
        message: 'Recovered lost data is not an image.',
      );
    }

    final files = response.files;

    if (files != null && files.isNotEmpty) {
      return List.unmodifiable(
        files.map((file) => AvatarPickedImage(path: file.path)),
      );
    }

    final file = response.file;
    return file == null
        ? const []
        : List.unmodifiable([AvatarPickedImage(path: file.path)]);
  }

  static ImageSource _mapSource(AvatarImagePickSource source) {
    return switch (source) {
      AvatarImagePickSource.gallery => ImageSource.gallery,
      AvatarImagePickSource.camera => ImageSource.camera,
    };
  }
}
