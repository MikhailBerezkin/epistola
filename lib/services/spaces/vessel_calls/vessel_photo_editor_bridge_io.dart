import 'package:flutter/material.dart';

import 'vessel_photo_processor.dart';

export 'vessel_photo_preparation_service.dart'
    show VesselPhotoPreparationService;
export 'vessel_photo_processor.dart' show PreparedVesselPhotoImages;
export 'vessel_photo_replacement_service.dart'
    show VesselPhotoReplacementResult, VesselPhotoReplacementService;

Widget buildPreparedVesselPhotoPreview(PreparedVesselPhotoImages images) {
  return Image.file(images.fullFile, fit: BoxFit.cover);
}
