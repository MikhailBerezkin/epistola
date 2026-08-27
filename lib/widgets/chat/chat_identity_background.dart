import 'package:flutter/material.dart';

import '../../services/avatar/avatar_image_loader.dart';
import '../identity/identity_background.dart';

class ChatIdentityBackground extends StatelessWidget {
  const ChatIdentityBackground({
    super.key,
    required this.stableKey,
    required this.name,
    required this.email,
    required this.child,
    this.storagePath,
    this.version,
    this.imageUrl,
    this.cacheKey,
    this.imageLoader,
  });

  final String stableKey;
  final String name;
  final String email;
  final String? storagePath;
  final int? version;
  final String? imageUrl;
  final String? cacheKey;
  final AvatarImageLoader? imageLoader;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IdentityBackground(
      stableKey: stableKey,
      name: name,
      email: email,
      storagePath: storagePath,
      version: version,
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      imageLoader: imageLoader,
      child: child,
    );
  }
}
