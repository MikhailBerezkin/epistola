import '../../../domain/models/vessel_registry.dart';
import '../../avatar/avatar_storage_gateway.dart';
import '../../avatar/firebase_avatar_storage_gateway.dart';
import 'vessel_photo_paths.dart';
import 'vessel_photo_pipeline_config.dart';
import 'vessel_photo_processor.dart';

typedef VesselPhotoVersionGenerator = int Function();

final class UploadedVesselPhoto {
  const UploadedVesselPhoto({
    required this.vesselKey,
    required this.version,
    required this.thumbnailPath,
    required this.fullPath,
  });

  final String vesselKey;
  final int version;
  final String thumbnailPath;
  final String fullPath;
}

final class VesselPhotoStorageService {
  VesselPhotoStorageService({
    required this._storage,
    VesselPhotoVersionGenerator? versionGenerator,
  }) : _versionGenerator = versionGenerator ?? _nextVersion;

  factory VesselPhotoStorageService.firebase() {
    return VesselPhotoStorageService(storage: FirebaseAvatarStorageGateway());
  }

  static int _lastVersion = 0;

  final AvatarStorageGateway _storage;
  final VesselPhotoVersionGenerator _versionGenerator;

  Future<UploadedVesselPhoto> upload({
    required VesselRegistryEntry vessel,
    required PreparedVesselPhotoImages images,
  }) async {
    await _validatePreparedImages(images);

    final version = _versionGenerator();

    if (version <= 0) {
      throw StateError('Generated vessel photo version must be positive.');
    }

    final vesselKey = VesselPhotoPaths.vesselKey(
      vesselUid: vessel.vesselUid,
      imo: vessel.imo,
    );

    final thumbnailPath = VesselPhotoPaths.thumbnail(
      vesselKey: vesselKey,
      version: version,
    );

    final fullPath = VesselPhotoPaths.full(
      vesselKey: vesselKey,
      version: version,
    );

    try {
      await _storage.uploadFile(
        file: images.thumbnailFile,
        path: thumbnailPath,
        type: 'vesselPhotoThumbnail',
        ownerType: 'vessel',
        ownerId: vesselKey,
        mimeType: VesselPhotoPipelineConfig.mimeType,
        version: version,
      );

      await _storage.uploadFile(
        file: images.fullFile,
        path: fullPath,
        type: 'vesselPhotoFull',
        ownerType: 'vessel',
        ownerId: vesselKey,
        mimeType: VesselPhotoPipelineConfig.mimeType,
        version: version,
      );

      return UploadedVesselPhoto(
        vesselKey: vesselKey,
        version: version,
        thumbnailPath: thumbnailPath,
        fullPath: fullPath,
      );
    } catch (error, stackTrace) {
      await deletePaths(thumbnailPath: thumbnailPath, fullPath: fullPath);

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> deletePaths({String? thumbnailPath, String? fullPath}) async {
    final paths = <String>{
      if (thumbnailPath?.trim().isNotEmpty == true) thumbnailPath!.trim(),
      if (fullPath?.trim().isNotEmpty == true) fullPath!.trim(),
    };

    for (final path in paths) {
      try {
        await _storage.deleteFile(path);
      } catch (_) {
        // Удаление старой или неудачно загруженной версии —
        // best effort. Оно не должно ломать основную операцию.
      }
    }
  }

  static Future<void> _validatePreparedImages(
    PreparedVesselPhotoImages images,
  ) async {
    final thumbnailFile = images.thumbnailFile;
    final fullFile = images.fullFile;

    if (!await thumbnailFile.exists()) {
      throw StateError('Prepared vessel thumbnail does not exist.');
    }

    if (!await fullFile.exists()) {
      throw StateError('Prepared vessel full photo does not exist.');
    }

    final thumbnailSize = await thumbnailFile.length();
    final fullSize = await fullFile.length();

    if (thumbnailSize <= 0 ||
        thumbnailSize >
            VesselPhotoPipelineConfig.thumbnail.hardMaximumSizeBytes) {
      throw StateError('Prepared vessel thumbnail has invalid size.');
    }

    if (fullSize <= 0 ||
        fullSize > VesselPhotoPipelineConfig.full.hardMaximumSizeBytes) {
      throw StateError('Prepared vessel full photo has invalid size.');
    }
  }

  static int _nextVersion() {
    final now = DateTime.now().microsecondsSinceEpoch;

    final version = now > _lastVersion ? now : _lastVersion + 1;

    _lastVersion = version;

    return version;
  }
}
