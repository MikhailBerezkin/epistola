import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/avatar/avatar_image_dependencies.dart';
import '../../services/avatar/avatar_image_loader.dart';
import 'avatar_fallback.dart';

class AvatarView extends StatefulWidget {
  final String stableKey;
  final String name;
  final String email;
  final double radius;
  final String? storagePath;
  final int? version;
  final int? maximumBytes;
  final AvatarImageLoader? imageLoader;
  final String? imageUrl;
  final String? cacheKey;

  const AvatarView({
    super.key,
    required this.stableKey,
    required this.name,
    required this.email,
    required this.radius,
    this.storagePath,
    this.version,
    this.maximumBytes,
    this.imageLoader,
    this.imageUrl,
    this.cacheKey,
  });

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> {
  Future<Uint8List?>? _imageBytes;

  @override
  void initState() {
    super.initState();
    _startPathLoad();
  }

  @override
  void didUpdateWidget(covariant AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.storagePath != widget.storagePath ||
        oldWidget.version != widget.version ||
        oldWidget.maximumBytes != widget.maximumBytes ||
        oldWidget.imageLoader != widget.imageLoader) {
      _startPathLoad();
    }
  }

  void _startPathLoad() {
    final path = widget.storagePath?.trim();
    final version = widget.version;
    final maximumBytes = widget.maximumBytes;

    if (path == null ||
        path.isEmpty ||
        version == null ||
        version <= 0 ||
        maximumBytes == null ||
        maximumBytes <= 0) {
      _imageBytes = null;
      return;
    }

    final loader = widget.imageLoader ?? defaultAvatarImageLoader;
    _imageBytes = loader.load(
      path: path,
      version: version,
      maxSizeBytes: maximumBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = AvatarFallback(
      stableKey: widget.stableKey,
      name: widget.name,
      email: widget.email,
      radius: widget.radius,
    );

    final imageBytes = _imageBytes;
    if (imageBytes != null) {
      return FutureBuilder<Uint8List?>(
        future: imageBytes,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError &&
              bytes != null) {
            return _buildClippedImage(
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.done) {
            return _buildLegacyImage(context, fallback);
          }

          return fallback;
        },
      );
    }

    return _buildLegacyImage(context, fallback);
  }

  Widget _buildLegacyImage(BuildContext context, Widget fallback) {
    final normalizedUrl = widget.imageUrl?.trim();

    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return fallback;
    }

    final diameter = widget.radius * 2;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final targetPixelSize = (diameter * devicePixelRatio).ceil().clamp(1, 1024);
    final normalizedCacheKey = widget.cacheKey?.trim();

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

  Widget _buildClippedImage(Widget image) {
    final diameter = widget.radius * 2;
    return ClipOval(
      child: SizedBox.square(dimension: diameter, child: image),
    );
  }
}
