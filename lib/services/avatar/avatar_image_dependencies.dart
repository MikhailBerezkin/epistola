import 'atomic_avatar_replacement_service.dart';
import 'avatar_image_cache.dart';
import 'avatar_image_loader.dart';
import 'avatar_image_preparation_service.dart';
import 'avatar_lost_data_recovery_coordinator.dart';
import 'avatar_replacement_controller.dart';
import 'avatar_storage_upload_service.dart';
import 'firebase_avatar_image_source.dart';
import 'firebase_avatar_storage_gateway.dart';
import 'firebase_user_avatar_metadata_gateway.dart';

AvatarImageLoader? _defaultAvatarImageLoader;

AvatarImageLoader get defaultAvatarImageLoader {
  return _defaultAvatarImageLoader ??= AvatarImageCache(
    source: FirebaseAvatarImageSource(),
  );
}

final AvatarLostDataRecoveryCoordinator
defaultAvatarLostDataRecoveryCoordinator = AvatarLostDataRecoveryCoordinator();

AvatarReplacementController createAvatarReplacementController() {
  return AvatarReplacementController(
    preparation: AvatarImagePreparationService(),
    replacement: AtomicAvatarReplacementService(
      storage: AvatarStorageUploadService(
        provider: FirebaseAvatarStorageGateway(),
      ),
      metadata: FirebaseUserAvatarMetadataGateway(),
    ),
  );
}
