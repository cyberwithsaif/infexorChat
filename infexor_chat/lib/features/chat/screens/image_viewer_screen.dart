import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../services/media_service.dart';

class ImageViewerScreen extends ConsumerStatefulWidget {
  final String imageUrl;
  final String senderName;
  final String caption;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.senderName = '',
    this.caption = '',
  });

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  final _transformationController = TransformationController();
  bool _isDownloading = false;
  CancelToken? _cancelToken;

  String get _resolvedUrl {
    if (widget.imageUrl.startsWith('http')) return widget.imageUrl;
    final serverRoot = ApiEndpoints.baseUrl.replaceAll('/api', '');
    return '$serverRoot${widget.imageUrl}';
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _downloadImage() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _cancelToken = CancelToken();
    });

    if (mounted) {
      _showMessage('Saving image...', duration: const Duration(seconds: 10));
    }

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(_resolvedUrl, filePath, cancelToken: _cancelToken);
      await Gal.putImage(filePath);

      // Tell backend we downloaded it so it can clean it up after 1 day
      ref.read(mediaServiceProvider).markDownloaded(widget.imageUrl);

      if (mounted) {
        _showMessage('Image saved to gallery');
      }
    } catch (e) {
      if (mounted) {
        if (CancelToken.isCancel(e as DioException)) {
          _showMessage('Download cancelled');
        } else {
          _showMessage('Failed to save image to gallery');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _cancelToken = null;
        });
      }
    }
  }

  void _cancelDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel();
    }
  }

  Future<void> _shareImage() async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'share_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(_resolvedUrl, filePath);

      await Share.shareXFiles([
        XFile(filePath),
      ], text: widget.caption.isNotEmpty ? widget.caption : null);
    } catch (e) {
      if (mounted) {
        _showMessage('Failed to share image');
      }
    }
  }

  void _showMessage(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), duration: duration));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        foregroundColor: Colors.white,
        title: widget.senderName.isNotEmpty
            ? Text(
                widget.senderName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareImage,
            tooltip: 'Share',
          ),
          // Download / Cancel button
          IconButton(
            icon: _isDownloading
                ? const Icon(Icons.close, color: Colors.white)
                : const Icon(Icons.download, color: Colors.white),
            onPressed: _isDownloading ? _cancelDownload : _downloadImage,
            tooltip: _isDownloading ? 'Cancel Download' : 'Download',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Hero(
                  tag: widget.imageUrl,
                  child: CachedNetworkImage(
                    imageUrl: _resolvedUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        Container(color: Colors.black),
                    errorWidget: (context, url, error) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: AppColors.textMuted,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.caption.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              color: Colors.black.withValues(alpha: 0.8),
              child: Text(
                widget.caption,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }
}
