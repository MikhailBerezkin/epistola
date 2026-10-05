import '../../../domain/models/vessel_registry.dart';
import 'vessel_photo_processor.dart';
import 'vessel_photo_storage_service.dart';
import 'vessel_registry_service.dart';

final class VesselPhotoReplacementResult {
  const VesselPhotoReplacementResult({
    required this.thumbnailPath,
    required this.fullPath,
    required this.version,
  });

  final String thumbnailPath;
  final String fullPath;
  final int version;
}

final class VesselPhotoReplacementService {
  VesselPhotoReplacementService({
    required this.storageService,
    required this.registryService,
  });

  factory VesselPhotoReplacementService.firebase() {
    return VesselPhotoReplacementService(
      storageService: VesselPhotoStorageService.firebase(),
      registryService: VesselRegistryService.firebase(),
    );
  }

  final VesselPhotoStorageService storageService;
  final VesselRegistryService registryService;

  Future<VesselPhotoReplacementResult> replace({
    required VesselRegistryEntry vessel,
    required PreparedVesselPhotoImages images,
    required String updatedBy,
  }) async {
    UploadedVesselPhoto? uploaded;

    try {
      uploaded = await storageService.upload(vessel: vessel, images: images);

      try {
        await registryService.saveVesselPhoto(
          vesselUid: vessel.vesselUid,
          thumbnailPath: uploaded.thumbnailPath,
          fullPath: uploaded.fullPath,
          version: uploaded.version,
          updatedBy: updatedBy,
        );
      } catch (error, stackTrace) {
        await storageService.deletePaths(
          thumbnailPath: uploaded.thumbnailPath,
          fullPath: uploaded.fullPath,
        );

        Error.throwWithStackTrace(error, stackTrace);
      }

      await _deletePreviousPhoto(vessel: vessel, uploaded: uploaded);

      return VesselPhotoReplacementResult(
        thumbnailPath: uploaded.thumbnailPath,
        fullPath: uploaded.fullPath,
        version: uploaded.version,
      );
    } finally {
      await images.cleanup();
    }
  }

  Future<void> _deletePreviousPhoto({
    required VesselRegistryEntry vessel,
    required UploadedVesselPhoto uploaded,
  }) async {
    final oldPaths = <String>{
      if (vessel.photoPath?.trim().isNotEmpty == true) vessel.photoPath!.trim(),
      if (vessel.photoThumbPath?.trim().isNotEmpty == true)
        vessel.photoThumbPath!.trim(),
      if (vessel.photoFullPath?.trim().isNotEmpty == true)
        vessel.photoFullPath!.trim(),
    };

    oldPaths.remove(uploaded.thumbnailPath);
    oldPaths.remove(uploaded.fullPath);

    for (final path in oldPaths) {
      await storageService.deletePaths(thumbnailPath: path);
    }
  }
}
