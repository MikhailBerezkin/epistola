import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/media_asset.dart';
import '../../domain/models/user_avatar.dart';
import '../media/media_paths.dart';
import 'avatar_compression_policy.dart';
import 'avatar_image_compressor_gateway.dart';
import 'avatar_image_crop_gateway.dart';
import 'avatar_image_pipeline_config.dart';
import 'avatar_image_processor.dart';
import 'firebase_user_avatar_metadata_gateway.dart';
import 'user_avatar_metadata_gateway.dart';

final class WebAvatarReplacementService {
  WebAvatarReplacementService({
    required this._contextProvider,
    ImagePicker? picker,
    FirebaseStorage? storage,
    UserAvatarMetadataGateway? metadata,
  }) : _picker = picker ?? ImagePicker(),
       _storage = storage ?? FirebaseStorage.instance,
       _metadata = metadata ?? FirebaseUserAvatarMetadataGateway();

  static const _providerName = 'firebase';
  static const _mimeType = 'image/jpeg';
  static const _ownerType = 'user';

  static const _maximumIntermediateDimension = 1024;
  static const _intermediateQuality = 100;

  static final _squareAspectRatio = CropAspectRatio(ratioX: 1, ratioY: 1);

  static int _lastVersion = 0;

  final BuildContext Function() _contextProvider;
  final ImagePicker _picker;
  final FirebaseStorage _storage;
  final UserAvatarMetadataGateway _metadata;

  Future<UserAvatar?> replaceFromGallery({required String uid}) {
    return _replace(uid: uid, source: ImageSource.gallery);
  }

  Future<UserAvatar?> replaceWithCamera({required String uid}) {
    return _replace(uid: uid, source: ImageSource.camera);
  }

  Future<UserAvatar?> _replace({
    required String uid,
    required ImageSource source,
  }) async {
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'UID must not be empty.');
    }

    final pickedImage = await _pick(source);

    if (pickedImage == null) {
      return null;
    }

    final croppedImage = await _crop(pickedImage.path);

    if (croppedImage == null) {
      return null;
    }

    final sourceBytes = await _readCroppedBytes(croppedImage);

    final thumbnailBytes = await _compressThumbnail(sourceBytes);
    final fullBytes = await _compressFull(sourceBytes);

    final version = _nextVersion();

    final uploadedAvatar = await _uploadAvatar(
      uid: normalizedUid,
      version: version,
      thumbnailBytes: thumbnailBytes,
      fullBytes: fullBytes,
    );

    late final UserAvatar? previousAvatar;

    try {
      previousAvatar = await _metadata.replace(
        uid: normalizedUid,
        avatar: uploadedAvatar,
      );
    } catch (error, stackTrace) {
      final activeVersion = error is AvatarVersionConflictException
          ? error.activeVersion
          : 0;

      await _deleteAvatarVersion(
        uid: normalizedUid,
        avatar: uploadedAvatar,
        activeVersion: activeVersion,
      );

      Error.throwWithStackTrace(error, stackTrace);
    }

    if (previousAvatar != null) {
      await _deleteAvatarVersion(
        uid: normalizedUid,
        avatar: previousAvatar,
        activeVersion: uploadedAvatar.version,
      );
    }

    return uploadedAvatar;
  }

  Future<XFile?> _pick(ImageSource source) async {
    try {
      return await _picker.pickImage(source: source);
    } on PlatformException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PlatformException(
          code: 'avatar_image_pick_failed',
          message: error.toString(),
        ),
        stackTrace,
      );
    }
  }

  Future<CroppedFile?> _crop(String sourcePath) async {
    final context = _contextProvider();

    if (!context.mounted) {
      return null;
    }

    final screenSize = MediaQuery.sizeOf(context);

    try {
      return await ImageCropper().cropImage(
        sourcePath: sourcePath,
        maxWidth: _maximumIntermediateDimension,
        maxHeight: _maximumIntermediateDimension,
        aspectRatio: _squareAspectRatio,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: _intermediateQuality,
        uiSettings: [
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.page,
            size: CropperSize(
              width: (screenSize.width * 0.9).round(),
              height: (screenSize.height * 0.68).round(),
            ),
            customRouteBuilder: (cropper, initCropper, crop, rotate, scale) {
              return MaterialPageRoute<String>(
                fullscreenDialog: true,
                builder: (_) {
                  return _WebAvatarCropperPage(
                    cropper: cropper,
                    initCropper: initCropper,
                    crop: crop,
                  );
                },
              );
            },
          ),
        ],
      );
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AvatarImageCropException(
          code: error.code.isEmpty ? 'crop_failed' : error.code,
          message: _messageOrFallback(
            error.message,
            'Failed to crop the avatar image.',
          ),
        ),
        stackTrace,
      );
    } on AvatarImageCropException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AvatarImageCropException(
          code: 'crop_failed',
          message: error.toString(),
        ),
        stackTrace,
      );
    }
  }

  Future<Uint8List> _readCroppedBytes(CroppedFile croppedImage) async {
    try {
      final bytes = await croppedImage.readAsBytes();

      if (bytes.isEmpty) {
        throw const AvatarImageProcessorException(
          code: 'cropped_image_empty',
          message: 'The cropped avatar image is empty.',
        );
      }

      return bytes;
    } on AvatarImageProcessorException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AvatarImageProcessorException(
          code: 'cropped_image_read_failed',
          message: 'Could not read the cropped avatar image: $error',
        ),
        stackTrace,
      );
    }
  }

  Future<Uint8List> _compressThumbnail(Uint8List sourceBytes) async {
    final config = AvatarImagePipelineConfig.thumbnail;

    final output = await _compressVariant(
      sourceBytes: sourceBytes,
      width: config.width,
      height: config.height,
      quality: config.qualityAttempts.single,
    );

    if (output.lengthInBytes >
        AvatarImagePipelineConfig.hardThumbnailSizeBytes) {
      throw AvatarImageHardLimitExceededException(
        actualBytes: output.lengthInBytes,
        maximumBytes: AvatarImagePipelineConfig.hardThumbnailSizeBytes,
      );
    }

    return output;
  }

  Future<Uint8List> _compressFull(Uint8List sourceBytes) async {
    final config = AvatarImagePipelineConfig.full;
    final qualities = config.qualityAttempts;

    for (
      var attemptIndex = 0;
      attemptIndex < qualities.length;
      attemptIndex++
    ) {
      final output = await _compressVariant(
        sourceBytes: sourceBytes,
        width: config.width,
        height: config.height,
        quality: qualities[attemptIndex],
      );

      final decision = AvatarCompressionPolicy.evaluateFullImage(
        fileSizeBytes: output.lengthInBytes,
        qualityAttemptIndex: attemptIndex,
      );

      switch (decision) {
        case AvatarCompressionDecision.accept:
          return output;

        case AvatarCompressionDecision.recompress:
          continue;

        case AvatarCompressionDecision.hardMaximumExceeded:
          throw AvatarImageHardLimitExceededException(
            actualBytes: output.lengthInBytes,
            maximumBytes: AvatarImagePipelineConfig.hardFullSizeBytes,
          );
      }
    }

    throw const AvatarImageProcessorException(
      code: 'full_output_missing',
      message: 'Avatar full image was not produced.',
    );
  }

  Future<Uint8List> _compressVariant({
    required Uint8List sourceBytes,
    required int width,
    required int height,
    required int quality,
  }) async {
    try {
      final output = await FlutterImageCompress.compressWithList(
        sourceBytes,
        minWidth: width,
        minHeight: height,
        quality: quality,
        rotate: 0,
        autoCorrectionAngle: true,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (output.isEmpty) {
        throw const AvatarImageCompressorException(
          code: 'compression_output_missing',
          message: 'Avatar compressor returned no output.',
        );
      }

      return output;
    } on AvatarImageCompressorException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AvatarImageCompressorException(
          code: 'compression_failed',
          message: 'Could not compress the avatar image: $error',
        ),
        stackTrace,
      );
    }
  }

  Future<UserAvatar> _uploadAvatar({
    required String uid,
    required int version,
    required Uint8List thumbnailBytes,
    required Uint8List fullBytes,
  }) async {
    _validateVersion(version);

    _validateImageSize(
      thumbnailBytes,
      AvatarImagePipelineConfig.hardThumbnailSizeBytes,
    );

    _validateImageSize(fullBytes, AvatarImagePipelineConfig.hardFullSizeBytes);

    final thumbnailPath = MediaPaths.userAvatarThumbnail(
      userId: uid,
      version: version,
    );

    final fullPath = MediaPaths.userAvatarFull(userId: uid, version: version);

    try {
      final thumbnail = await _uploadVariant(
        bytes: thumbnailBytes,
        storagePath: thumbnailPath,
        type: 'userAvatarThumbnail',
        uid: uid,
        version: version,
        width: AvatarImagePipelineConfig.thumbnail.width,
        height: AvatarImagePipelineConfig.thumbnail.height,
      );

      final full = await _uploadVariant(
        bytes: fullBytes,
        storagePath: fullPath,
        type: 'userAvatarFull',
        uid: uid,
        version: version,
        width: AvatarImagePipelineConfig.full.width,
        height: AvatarImagePipelineConfig.full.height,
      );

      return UserAvatar(thumbnail: thumbnail, full: full);
    } catch (error, stackTrace) {
      await _deleteBestEffort(thumbnailPath);
      await _deleteBestEffort(fullPath);

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<MediaAsset> _uploadVariant({
    required Uint8List bytes,
    required String storagePath,
    required String type,
    required String uid,
    required int version,
    required int width,
    required int height,
  }) async {
    final metadata = SettableMetadata(
      contentType: _mimeType,
      customMetadata: {
        'type': type,
        'ownerType': _ownerType,
        'ownerId': uid,
        'version': version.toString(),
      },
    );

    await _storage.ref(storagePath).putData(bytes, metadata);

    final now = DateTime.now();

    return MediaAsset(
      id: storagePath,
      provider: _providerName,
      path: storagePath,
      type: type,
      ownerType: _ownerType,
      ownerId: uid,
      mimeType: _mimeType,
      sizeBytes: bytes.lengthInBytes,
      width: width,
      height: height,
      version: version,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _deleteAvatarVersion({
    required String uid,
    required UserAvatar avatar,
    required int activeVersion,
  }) async {
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty ||
        avatar.version <= 0 ||
        avatar.version == activeVersion ||
        avatar.provider != _providerName ||
        avatar.thumbnail.ownerId != normalizedUid ||
        avatar.full.ownerId != normalizedUid) {
      return;
    }

    final expectedThumbnailPath = MediaPaths.userAvatarThumbnail(
      userId: normalizedUid,
      version: avatar.version,
    );

    final expectedFullPath = MediaPaths.userAvatarFull(
      userId: normalizedUid,
      version: avatar.version,
    );

    if (avatar.thumbnailStoragePath != expectedThumbnailPath ||
        avatar.fullStoragePath != expectedFullPath) {
      return;
    }

    await _deleteBestEffort(expectedThumbnailPath);
    await _deleteBestEffort(expectedFullPath);
  }

  Future<void> _deleteBestEffort(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } catch (_) {
      // Cleanup is best-effort and must not replace the original result.
    }
  }

  static int _nextVersion() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final version = now > _lastVersion ? now : _lastVersion + 1;

    _lastVersion = version;

    return version;
  }

  static void _validateVersion(int version) {
    if (version <= 0) {
      throw ArgumentError.value(
        version,
        'version',
        'Generated avatar version must be positive.',
      );
    }
  }

  static void _validateImageSize(Uint8List bytes, int maximumBytes) {
    if (bytes.lengthInBytes > maximumBytes) {
      throw AvatarImageHardLimitExceededException(
        actualBytes: bytes.lengthInBytes,
        maximumBytes: maximumBytes,
      );
    }
  }

  static String _messageOrFallback(String? message, String fallback) {
    final normalized = message?.trim();

    return normalized == null || normalized.isEmpty ? fallback : normalized;
  }
}

final class _WebAvatarCropperPage extends StatefulWidget {
  const _WebAvatarCropperPage({
    required this.cropper,
    required this.initCropper,
    required this.crop,
  });

  final Widget cropper;
  final VoidCallback initCropper;
  final Future<String?> Function() crop;

  @override
  State<_WebAvatarCropperPage> createState() {
    return _WebAvatarCropperPageState();
  }
}

final class _WebAvatarCropperPageState extends State<_WebAvatarCropperPage> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    widget.initCropper();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await widget.crop();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }

      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Отмена',
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          icon: const Icon(Icons.close),
        ),
        title: const Text('Обрезка'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Сохранение…' : 'Сохранить'),
            ),
          ),
        ],
      ),
      body: SafeArea(child: Center(child: widget.cropper)),
    );
  }
}
