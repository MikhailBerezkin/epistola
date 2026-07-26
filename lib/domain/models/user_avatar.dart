import 'media_asset.dart';

class UserAvatar {
  final MediaAsset thumbnail;
  final MediaAsset full;

  const UserAvatar({required this.thumbnail, required this.full});

  int get version => full.version;

  String get provider => full.provider;

  DateTime? get updatedAt => full.updatedAt ?? thumbnail.updatedAt;

  String? get thumbnailUrl => thumbnail.downloadUrl;

  String? get fullUrl => full.downloadUrl;

  String get thumbnailStoragePath => thumbnail.path;

  String get fullStoragePath => full.path;

  bool get hasThumbnail {
    return thumbnailUrl?.trim().isNotEmpty ?? false;
  }

  bool get hasFullImage {
    return fullUrl?.trim().isNotEmpty ?? false;
  }

  bool get isComplete {
    final ownerId = full.ownerId?.trim();

    return version > 0 &&
        provider.trim().isNotEmpty &&
        ownerId != null &&
        ownerId.isNotEmpty &&
        thumbnail.version == version &&
        thumbnail.provider == provider &&
        thumbnail.ownerId == full.ownerId &&
        hasThumbnail &&
        hasFullImage;
  }

  String thumbnailCacheKey(String userId) {
    return 'user-avatar:$userId:v$version:thumb';
  }

  String fullCacheKey(String userId) {
    return 'user-avatar:$userId:v$version:full';
  }
}
