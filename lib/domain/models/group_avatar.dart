import 'media_asset.dart';

class GroupAvatar {
  final MediaAsset thumbnail;
  final MediaAsset full;

  const GroupAvatar({required this.thumbnail, required this.full});

  int get version => full.version;

  String get provider => full.provider;

  DateTime? get updatedAt => full.updatedAt ?? thumbnail.updatedAt;

  String? get thumbnailUrl => thumbnail.downloadUrl;

  String? get fullUrl => full.downloadUrl;

  String get thumbnailStoragePath => thumbnail.path;

  String get fullStoragePath => full.path;

  bool get hasThumbnail => thumbnailStoragePath.trim().isNotEmpty;

  bool get hasFullImage => fullStoragePath.trim().isNotEmpty;

  int? get thumbnailSizeBytes => thumbnail.sizeBytes;

  int? get fullSizeBytes => full.sizeBytes;

  bool get isComplete {
    final ownerId = full.ownerId?.trim();

    return version > 0 &&
        provider.trim().isNotEmpty &&
        ownerId != null &&
        ownerId.isNotEmpty &&
        thumbnail.version == version &&
        thumbnail.provider == provider &&
        thumbnail.ownerId == full.ownerId &&
        thumbnail.ownerType == 'group' &&
        full.ownerType == 'group' &&
        hasThumbnail &&
        hasFullImage;
  }

  bool get hasPersistableMetadata {
    final thumbnailSize = thumbnailSizeBytes;
    final fullSize = fullSizeBytes;

    return isComplete &&
        thumbnailSize != null &&
        thumbnailSize >= 0 &&
        fullSize != null &&
        fullSize >= 0 &&
        updatedAt != null;
  }

  String thumbnailCacheKey(String chatId) {
    return 'group-avatar:$chatId:v$version:thumb';
  }

  String fullCacheKey(String chatId) {
    return 'group-avatar:$chatId:v$version:full';
  }
}
