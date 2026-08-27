import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/avatar/avatar_image_dependencies.dart';
import '../../services/avatar/avatar_image_loader.dart';
import '../../services/avatar/avatar_image_pipeline_config.dart';
import '../avatar/avatar_initials.dart';

class IdentityBackground extends StatefulWidget {
  const IdentityBackground({
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
  State<IdentityBackground> createState() {
    return _IdentityBackgroundState();
  }
}

class _IdentityBackgroundState extends State<IdentityBackground> {
  Future<Uint8List?>? _imageBytes;

  @override
  void initState() {
    super.initState();
    _startPathLoad();
  }

  @override
  void didUpdateWidget(covariant IdentityBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.storagePath != widget.storagePath ||
        oldWidget.version != widget.version ||
        oldWidget.imageLoader != widget.imageLoader) {
      _startPathLoad();
    }
  }

  void _startPathLoad() {
    final path = widget.storagePath?.trim();
    final version = widget.version;

    if (path == null || path.isEmpty || version == null || version <= 0) {
      _imageBytes = null;
      return;
    }

    final loader = widget.imageLoader ?? defaultAvatarImageLoader;

    _imageBytes = loader.load(
      path: path,
      version: version,
      maxSizeBytes: AvatarImagePipelineConfig.hardFullSizeBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(context, constraints),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.46, 1],
                  colors: [
                    Color(0x66000000),
                    Color(0x08000000),
                    Color(0xD9000000),
                  ],
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }

  Widget _buildBackground(BuildContext context, BoxConstraints constraints) {
    final imageBytes = _imageBytes;

    if (imageBytes == null) {
      return _buildLegacyImageOrFallback(context, constraints);
    }

    return FutureBuilder<Uint8List?>(
      future: imageBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;

        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            bytes != null) {
          return SizedBox.expand(
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return _buildLegacyImageOrFallback(context, constraints);
              },
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.done) {
          return _buildLegacyImageOrFallback(context, constraints);
        }

        return _buildFallback(context);
      },
    );
  }

  Widget _buildLegacyImageOrFallback(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final imageUrl = widget.imageUrl?.trim();

    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildFallback(context);
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    final targetWidth = (constraints.maxWidth * devicePixelRatio)
        .ceil()
        .clamp(1, 2048)
        .toInt();

    final targetHeight = (constraints.maxHeight * devicePixelRatio)
        .ceil()
        .clamp(1, 2048)
        .toInt();

    final normalizedCacheKey = widget.cacheKey?.trim();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: normalizedCacheKey == null || normalizedCacheKey.isEmpty
          ? null
          : normalizedCacheKey,
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      fit: BoxFit.cover,
      memCacheWidth: targetWidth,
      memCacheHeight: targetHeight,
      maxWidthDiskCache: targetWidth,
      maxHeightDiskCache: targetHeight,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: (context, url) {
        return _buildFallback(context);
      },
      errorWidget: (context, url, error) {
        return _buildFallback(context);
      },
    );
  }

  Widget _buildFallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final colorIndex = AvatarInitials.stablePaletteIndex(
      stableKey: widget.stableKey,
      paletteLength: 4,
    );

    final palette = <List<Color>>[
      [
        colorScheme.primaryContainer,
        colorScheme.primary,
        colorScheme.onPrimaryContainer,
      ],
      [
        colorScheme.secondaryContainer,
        colorScheme.secondary,
        colorScheme.onSecondaryContainer,
      ],
      [
        colorScheme.tertiaryContainer,
        colorScheme.tertiary,
        colorScheme.onTertiaryContainer,
      ],
      [
        colorScheme.surfaceContainerHighest,
        colorScheme.surfaceContainer,
        colorScheme.onSurfaceVariant,
      ],
    ];

    final colors = palette[colorIndex];

    final initials = AvatarInitials.resolve(
      name: widget.name,
      email: widget.email,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors[0], colors[1]],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          maxLines: 1,
          style: TextStyle(
            color: colors[2].withValues(alpha: 0.82),
            fontSize: 86,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
