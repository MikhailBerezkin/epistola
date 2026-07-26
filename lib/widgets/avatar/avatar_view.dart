import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'avatar_fallback.dart';

class AvatarView extends StatelessWidget {
  final String stableKey;
  final String name;
  final String email;
  final double radius;
  final String? imageUrl;
  final String? cacheKey;

  const AvatarView({
    super.key,
    required this.stableKey,
    required this.name,
    required this.email,
    required this.radius,
    this.imageUrl,
    this.cacheKey,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = AvatarFallback(
      stableKey: stableKey,
      name: name,
      email: email,
      radius: radius,
    );

    final normalizedUrl = imageUrl?.trim();

    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return fallback;
    }

    final diameter = radius * 2;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    final targetPixelSize = (diameter * devicePixelRatio).ceil().clamp(1, 1024);

    final normalizedCacheKey = cacheKey?.trim();

    return ClipOval(
      child: SizedBox.square(
        dimension: diameter,
        child: CachedNetworkImage(
          imageUrl: normalizedUrl,
          cacheKey: normalizedCacheKey == null || normalizedCacheKey.isEmpty
              ? null
              : normalizedCacheKey,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          memCacheWidth: targetPixelSize,
          memCacheHeight: targetPixelSize,
          maxWidthDiskCache: targetPixelSize,
          maxHeightDiskCache: targetPixelSize,
          fadeInDuration: const Duration(milliseconds: 150),
          fadeOutDuration: const Duration(milliseconds: 100),
          placeholder: (context, url) => fallback,
          errorWidget: (context, url, error) => fallback,
        ),
      ),
    );
  }
}
