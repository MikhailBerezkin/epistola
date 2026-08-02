import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../domain/models/image_message_metadata.dart';
import '../services/media/media_storage_service.dart';

class ImageMessageViewerScreen extends StatefulWidget {
  const ImageMessageViewerScreen({super.key, required this.metadata});

  final ImageMessageMetadata metadata;

  @override
  State<ImageMessageViewerScreen> createState() =>
      _ImageMessageViewerScreenState();
}

class _ImageMessageViewerScreenState extends State<ImageMessageViewerScreen> {
  static final MediaStorageService _storageService = MediaStorageService();

  final TransformationController _transformationController =
      TransformationController();

  late Future<String> _downloadUrlFuture;

  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _downloadUrlFuture = _loadDownloadUrl();
  }

  Future<String> _loadDownloadUrl() {
    return _storageService.getDownloadUrl(widget.metadata.fullStoragePath);
  }

  void _retry() {
    _transformationController.value = Matrix4.identity();

    setState(() {
      _downloadUrlFuture = _loadDownloadUrl();
    });
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    if (currentScale > 1.01) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    const scale = 2.5;

    final translation = Matrix4.translationValues(
      -_doubleTapPosition.dx * (scale - 1),
      -_doubleTapPosition.dy * (scale - 1),
      0,
    );

    final zoom = Matrix4.diagonal3Values(scale, scale, 1);

    _transformationController.value = translation * zoom;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Фотография'),
        ),
        body: FutureBuilder<String>(
          future: _downloadUrlFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ViewerLoadError(onRetry: _retry);
            }

            final downloadUrl = snapshot.data;

            if (downloadUrl == null || downloadUrl.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTapDown: _handleDoubleTapDown,
              onDoubleTap: _handleDoubleTap,
              child: Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1,
                  maxScale: 5,
                  boundaryMargin: const EdgeInsets.all(80),
                  child: CachedNetworkImage(
                    imageUrl: downloadUrl,
                    cacheKey: widget.metadata.fullCacheKey,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, _) {
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorWidget: (context, _, _) {
                      return _ViewerLoadError(onRetry: _retry);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ViewerLoadError extends StatelessWidget {
  const _ViewerLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onRetry,
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 40,
                ),
                SizedBox(height: 12),
                Text(
                  'Не удалось открыть фотографию',
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 8),
                Text(
                  'Нажмите, чтобы повторить',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
