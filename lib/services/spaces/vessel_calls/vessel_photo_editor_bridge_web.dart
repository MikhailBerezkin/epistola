import 'package:flutter/material.dart';

import '../../../domain/models/vessel_registry.dart';

final class PreparedVesselPhotoImages {
  const PreparedVesselPhotoImages();

  Future<void> cleanup() async {}
}

final class VesselPhotoPreparationService {
  const VesselPhotoPreparationService();

  Future<PreparedVesselPhotoImages?> prepareFromGallery() async {
    return null;
  }

  Future<PreparedVesselPhotoImages?> prepareWithCamera() async {
    return null;
  }

  Future<PreparedVesselPhotoImages?> prepareRecoveredLostImage() async {
    return null;
  }
}

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
  const VesselPhotoReplacementService();

  factory VesselPhotoReplacementService.firebase() {
    return const VesselPhotoReplacementService();
  }

  Future<VesselPhotoReplacementResult> replace({
    required VesselRegistryEntry vessel,
    required PreparedVesselPhotoImages images,
    required String updatedBy,
  }) {
    throw UnsupportedError(
      'Vessel photo editing is not supported in EpiLite Web.',
    );
  }
}

Widget buildPreparedVesselPhotoPreview(PreparedVesselPhotoImages images) {
  return const SizedBox.shrink();
}
