import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/models/image_message_limits.dart';
import '../../domain/models/image_message_metadata.dart';
import '../../domain/models/media_asset.dart';
import '../chat/image_message_remote_cleanup_service.dart';
import 'media_paths.dart';

typedef ImageMessageStorageUpload =
    Future<void> Function({
      required File file,
      required String path,
      required String contentType,
      required Map<String, String> customMetadata,
    });

typedef ImageMessageStorageDelete = Future<void> Function(String path);

final class FirebaseImageMessageStorageAdapter
    implements ImageMessageRemoteCleanupGateway {
  FirebaseImageMessageStorageAdapter({
    FirebaseStorage? storage,
    ImageMessageStorageUpload? upload,
    ImageMessageStorageDelete? delete,
  }) {
    final hasCustomUpload = upload != null;
    final hasCustomDelete = delete != null;

    if (hasCustomUpload != hasCustomDelete) {
      throw ArgumentError('Provide both custom upload and delete callbacks.');
    }

    if (storage != null && hasCustomUpload) {
      throw ArgumentError(
        'Provide either FirebaseStorage or custom callbacks, not both.',
      );
    }

    if (upload != null && delete != null) {
      _upload = upload;
      _delete = delete;
      return;
    }

    final resolvedStorage = storage ?? FirebaseStorage.instance;

    _upload = _createFirebaseUpload(resolvedStorage);
    _delete = _createFirebaseDelete(resolvedStorage);
  }

  static final RegExp _canonicalStoragePathPattern = RegExp(
    r'^chat_media/[^/]+/messages/[^/]+/'
    r'v[1-9][0-9]*/(?:thumb|full)\.jpg$',
  );

  late final ImageMessageStorageUpload _upload;
  late final ImageMessageStorageDelete _delete;

  Future<MediaAsset> uploadThumbnail({
    required File file,
    required String uploaderId,
    required String chatId,
    required String messageId,
    required int version,
    required int width,
    required int height,
    bool usesFirstPrivateImageGrant = false,
  }) {
    return _uploadVariant(
      variant: _ImageMessageStorageVariant.thumbnail,
      file: file,
      uploaderId: uploaderId,
      chatId: chatId,
      messageId: messageId,
      version: version,
      width: width,
      height: height,
      usesFirstPrivateImageGrant: usesFirstPrivateImageGrant,
    );
  }

  Future<MediaAsset> uploadFull({
    required File file,
    required String uploaderId,
    required String chatId,
    required String messageId,
    required int version,
    required int width,
    required int height,
    bool usesFirstPrivateImageGrant = false,
  }) {
    return _uploadVariant(
      variant: _ImageMessageStorageVariant.full,
      file: file,
      uploaderId: uploaderId,
      chatId: chatId,
      messageId: messageId,
      version: version,
      width: width,
      height: height,
      usesFirstPrivateImageGrant: usesFirstPrivateImageGrant,
    );
  }

  @override
  Future<void> deleteFile(String path) {
    if (!_canonicalStoragePathPattern.hasMatch(path)) {
      throw ArgumentError.value(
        path,
        'path',
        'Only canonical image-message Storage paths may be deleted.',
      );
    }

    return _delete(path);
  }

  Future<MediaAsset> _uploadVariant({
    required _ImageMessageStorageVariant variant,
    required File file,
    required String uploaderId,
    required String chatId,
    required String messageId,
    required int version,
    required int width,
    required int height,
    required bool usesFirstPrivateImageGrant,
  }) async {
    _validateIdentifier(value: uploaderId, argumentName: 'uploaderId');

    _validateIdentifier(value: chatId, argumentName: 'chatId');

    _validateIdentifier(value: messageId, argumentName: 'messageId');

    if (version <= 0) {
      throw ArgumentError.value(
        version,
        'version',
        'Version must be greater than zero.',
      );
    }

    final maxDimension = switch (variant) {
      _ImageMessageStorageVariant.thumbnail =>
        ImageMessageLimits.maxThumbnailDimension,
      _ImageMessageStorageVariant.full => ImageMessageLimits.maxFullDimension,
    };

    if (width <= 0 || width > maxDimension) {
      throw ArgumentError.value(
        width,
        'width',
        'Width must be between 1 and $maxDimension.',
      );
    }

    if (height <= 0 || height > maxDimension) {
      throw ArgumentError.value(
        height,
        'height',
        'Height must be between 1 and $maxDimension.',
      );
    }

    if (!await file.exists()) {
      throw StateError('Image file does not exist: ${file.path}');
    }

    final sizeBytes = await file.length();

    final maxSizeBytes = switch (variant) {
      _ImageMessageStorageVariant.thumbnail =>
        ImageMessageLimits.maxThumbnailSizeBytes,
      _ImageMessageStorageVariant.full => ImageMessageLimits.maxFullSizeBytes,
    };

    if (sizeBytes <= 0 || sizeBytes > maxSizeBytes) {
      throw ArgumentError.value(
        sizeBytes,
        'file',
        'Image size must be between 1 and $maxSizeBytes bytes.',
      );
    }

    final path = switch (variant) {
      _ImageMessageStorageVariant.thumbnail =>
        MediaPaths.chatMessageImageThumbnail(
          chatId: chatId,
          messageId: messageId,
          version: version,
        ),
      _ImageMessageStorageVariant.full => MediaPaths.chatMessageImageFull(
        chatId: chatId,
        messageId: messageId,
        version: version,
      ),
    };

    final versionMetadata = 'v$version';

    final customMetadata = <String, String>{
      'uploaderId': uploaderId,
      'chatId': chatId,
      'messageId': messageId,
      'version': versionMetadata,
      if (usesFirstPrivateImageGrant) 'uploadGrantType': 'first_private_image',
    };

    await _upload(
      file: file,
      path: path,
      contentType: ImageMessageMetadata.supportedMimeType,
      customMetadata: customMetadata,
    );

    final now = DateTime.now();

    return MediaAsset(
      id: switch (variant) {
        _ImageMessageStorageVariant.thumbnail =>
          'image-message-$messageId-v$version-thumb',
        _ImageMessageStorageVariant.full =>
          'image-message-$messageId-v$version-full',
      },
      provider: ImageMessageMetadata.supportedProvider,
      path: path,
      type: switch (variant) {
        _ImageMessageStorageVariant.thumbnail =>
          ImageMessageMetadata.thumbnailAssetType,
        _ImageMessageStorageVariant.full => ImageMessageMetadata.fullAssetType,
      },
      ownerType: ImageMessageMetadata.messageOwnerType,
      ownerId: messageId,
      mimeType: ImageMessageMetadata.supportedMimeType,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      version: version,
      createdAt: now,
      updatedAt: now,
    );
  }

  static void _validateIdentifier({
    required String value,
    required String argumentName,
  }) {
    if (value.isEmpty || value != value.trim()) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must be a non-empty trimmed string.',
      );
    }

    if (value.contains('/')) {
      throw ArgumentError.value(
        value,
        argumentName,
        '$argumentName must not contain a slash.',
      );
    }
  }

  static ImageMessageStorageUpload _createFirebaseUpload(
    FirebaseStorage storage,
  ) {
    return ({
      required File file,
      required String path,
      required String contentType,
      required Map<String, String> customMetadata,
    }) async {
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: customMetadata,
      );

      await storage.ref(path).putFile(file, metadata);
    };
  }

  static ImageMessageStorageDelete _createFirebaseDelete(
    FirebaseStorage storage,
  ) {
    return (path) {
      return storage.ref(path).delete();
    };
  }
}

enum _ImageMessageStorageVariant { thumbnail, full }
