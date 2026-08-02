import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../domain/models/image_message_metadata.dart';
import '../screens/image_message_viewer_screen.dart';
import '../services/media/media_storage_service.dart';

class ImageMessageThumbnail extends StatefulWidget {
  const ImageMessageThumbnail({super.key, required this.metadata});

  final ImageMessageMetadata metadata;

  @override
  State<ImageMessageThumbnail> createState() => _ImageMessageThumbnailState();
}

class _ImageMessageThumbnailState extends State<ImageMessageThumbnail> {
  static final MediaStorageService _storageService = MediaStorageService();

  late Future<String> _downloadUrlFuture;

  @override
  void initState() {
    super.initState();
    _downloadUrlFuture = _loadDownloadUrl();
  }

  @override
  void didUpdateWidget(covariant ImageMessageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.metadata.thumbnailCacheKey !=
        widget.metadata.thumbnailCacheKey) {
      _downloadUrlFuture = _loadDownloadUrl();
    }
  }

  Future<String> _loadDownloadUrl() {
    return _storageService.getDownloadUrl(widget.metadata.thumbnailStoragePath);
  }

  void _openViewer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return ImageMessageViewerScreen(metadata: widget.metadata);
        },
      ),
    );
  }

  void _retryThumbnail() {
    setState(() {
      _downloadUrlFuture = _loadDownloadUrl();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.metadata.thumbnailWidth ?? 1;

    final height = widget.metadata.thumbnailHeight ?? 1;

    final aspectRatio = width > 0 && height > 0 ? width / height : 4 / 3;

    return Semantics(
      button: true,
      label: 'Открыть фотографию',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openViewer,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: FutureBuilder<String>(
              future: _downloadUrlFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ImageLoadError(onRetry: _retryThumbnail);
                }

                final downloadUrl = snapshot.data;

                if (downloadUrl == null || downloadUrl.isEmpty) {
                  return ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                return CachedNetworkImage(
                  imageUrl: downloadUrl,
                  cacheKey: widget.metadata.thumbnailCacheKey,
                  fit: BoxFit.cover,
                  placeholder: (context, _) {
                    return ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                  errorWidget: (context, _, _) {
                    return _ImageLoadError(onRetry: _retryThumbnail);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageLoadError extends StatelessWidget {
  const _ImageLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onRetry,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined),
              const SizedBox(height: 6),
              Text('Повторить', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
