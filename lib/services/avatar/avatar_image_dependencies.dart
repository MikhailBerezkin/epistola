import 'avatar_image_cache.dart';
import 'avatar_image_loader.dart';
import 'firebase_avatar_image_source.dart';

AvatarImageLoader? _defaultAvatarImageLoader;

AvatarImageLoader get defaultAvatarImageLoader {
  return _defaultAvatarImageLoader ??= AvatarImageCache(
    source: FirebaseAvatarImageSource(),
  );
}
