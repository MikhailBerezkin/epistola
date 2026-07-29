import '../../domain/models/group_avatar.dart';
import 'avatar_image_processor.dart';
import 'group_avatar_metadata_gateway.dart';
import 'group_avatar_storage_upload_service.dart';

typedef GroupAvatarVersionGenerator = int Function();

final class AtomicGroupAvatarReplacementService {
  factory AtomicGroupAvatarReplacementService({
    required GroupAvatarStorageUploadService storage,
    required GroupAvatarMetadataGateway metadata,
    GroupAvatarVersionGenerator? versionGenerator,
  }) {
    return AtomicGroupAvatarReplacementService._(
      storage,
      metadata,
      versionGenerator ?? _nextVersion,
    );
  }

  AtomicGroupAvatarReplacementService._(
    this._storage,
    this._metadata,
    this._versionGenerator,
  );

  final GroupAvatarStorageUploadService _storage;
  final GroupAvatarMetadataGateway _metadata;
  final GroupAvatarVersionGenerator _versionGenerator;

  static int _lastVersion = 0;

  Future<GroupAvatar> replace({
    required String chatId,
    required PreparedAvatarImages images,
  }) async {
    GroupAvatar? uploadedAvatar;

    try {
      final version = _versionGenerator();
      _validateVersion(version);

      uploadedAvatar = await _storage.upload(
        chatId: chatId,
        version: version,
        images: images,
      );

      late final GroupAvatar? previousAvatar;

      try {
        previousAvatar = await _metadata.replace(
          chatId: chatId,
          avatar: uploadedAvatar,
        );
      } catch (error, stackTrace) {
        final activeVersion = error is GroupAvatarVersionConflictException
            ? error.activeVersion
            : 0;

        await _storage.deleteAvatarVersion(
          chatId: chatId,
          avatar: uploadedAvatar,
          activeVersion: activeVersion,
        );

        Error.throwWithStackTrace(error, stackTrace);
      }

      if (previousAvatar != null) {
        await _storage.deleteAvatarVersion(
          chatId: chatId,
          avatar: previousAvatar,
          activeVersion: uploadedAvatar.version,
        );
      }

      return uploadedAvatar;
    } finally {
      try {
        await images.cleanup();
      } catch (_) {
        // Локальный cleanup не должен менять результат удалённой операции.
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
        'Generated group avatar version must be positive.',
      );
    }
  }
}
