import '../../domain/models/user_avatar.dart';
import 'avatar_image_processor.dart';
import 'avatar_storage_upload_service.dart';
import 'user_avatar_metadata_gateway.dart';

typedef AvatarVersionGenerator = int Function();

final class AtomicAvatarReplacementService {
  factory AtomicAvatarReplacementService({
    required AvatarStorageUploadService storage,
    required UserAvatarMetadataGateway metadata,
    AvatarVersionGenerator? versionGenerator,
  }) {
    return AtomicAvatarReplacementService._(
      storage,
      metadata,
      versionGenerator ?? _nextVersion,
    );
  }

  AtomicAvatarReplacementService._(
    this._storage,
    this._metadata,
    this._versionGenerator,
  );

  final AvatarStorageUploadService _storage;
  final UserAvatarMetadataGateway _metadata;
  final AvatarVersionGenerator _versionGenerator;

  static int _lastVersion = 0;

  Future<UserAvatar> replace({
    required String uid,
    required PreparedAvatarImages images,
  }) async {
    UserAvatar? uploadedAvatar;

    try {
      final version = _versionGenerator();
      _validateVersion(version);

      uploadedAvatar = await _storage.upload(
        uid: uid,
        version: version,
        images: images,
      );

      late final UserAvatar? previousAvatar;

      try {
        previousAvatar = await _metadata.replace(
          uid: uid,
          avatar: uploadedAvatar,
        );
      } catch (error, stackTrace) {
        final activeVersion = error is AvatarVersionConflictException
            ? error.activeVersion
            : 0;

        await _storage.deleteAvatarVersion(
          uid: uid,
          avatar: uploadedAvatar,
          activeVersion: activeVersion,
        );
        Error.throwWithStackTrace(error, stackTrace);
      }

      if (previousAvatar != null) {
        await _storage.deleteAvatarVersion(
          uid: uid,
          avatar: previousAvatar,
          activeVersion: uploadedAvatar.version,
        );
      }

      return uploadedAvatar;
    } finally {
      try {
        await images.cleanup();
      } catch (_) {
        // Local cleanup must not replace the remote operation result.
      }
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
}
