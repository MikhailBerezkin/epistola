import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

typedef VesselPhotoUrlResolver = Future<String> Function(String storagePath);

final class VesselPhotoImage extends StatefulWidget {
  const VesselPhotoImage({
    required this.storagePath,
    required this.version,
    required this.width,
    required this.height,
    required this.fallbackBuilder,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fit = BoxFit.cover,
    this.urlResolver,
    super.key,
  });

  final String? storagePath;
  final int? version;

  final double width;
  final double height;

  final BorderRadius borderRadius;
  final BoxFit fit;

  final WidgetBuilder fallbackBuilder;

  final VesselPhotoUrlResolver? urlResolver;

  @override
  State<VesselPhotoImage> createState() {
    return _VesselPhotoImageState();
  }
}

final class _VesselPhotoImageState extends State<VesselPhotoImage> {
  Future<String>? _downloadUrlFuture;

  @override
  void initState() {
    super.initState();

    _refreshDownloadUrl();
  }

  @override
  void didUpdateWidget(covariant VesselPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.storagePath != widget.storagePath ||
        oldWidget.version != widget.version ||
        oldWidget.urlResolver != widget.urlResolver) {
      _refreshDownloadUrl();
    }
  }

  void _refreshDownloadUrl() {
    final storagePath = widget.storagePath?.trim() ?? '';

    if (storagePath.isEmpty) {
      _downloadUrlFuture = null;
      return;
    }

    final resolver = widget.urlResolver ?? _firebaseDownloadUrl;

    _downloadUrlFuture = resolver(storagePath);
  }

  String get _cacheKey {
    final storagePath = widget.storagePath?.trim() ?? '';
    final version = widget.version;

    if (version == null || version <= 0) {
      return storagePath;
    }

    return '$storagePath#v$version';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final future = _downloadUrlFuture;

    if (future == null) {
      return widget.fallbackBuilder(context);
    }

    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        final downloadUrl = snapshot.data?.trim() ?? '';

        if (snapshot.connectionState != ConnectionState.done ||
            downloadUrl.isEmpty) {
          return widget.fallbackBuilder(context);
        }

        return CachedNetworkImage(
          imageUrl: downloadUrl,

          // Ключ основан на Firebase Storage path,
          // а не на download URL с токеном.
          cacheKey: _cacheKey,

          width: widget.width,
          height: widget.height,
          fit: widget.fit,

          fadeInDuration: const Duration(milliseconds: 180),

          placeholder: (context, url) {
            return widget.fallbackBuilder(context);
          },

          errorWidget: (context, url, error) {
            return widget.fallbackBuilder(context);
          },
        );
      },
    );
  }

  static Future<String> _firebaseDownloadUrl(String storagePath) {
    return FirebaseStorage.instance.ref(storagePath).getDownloadURL();
  }
}
