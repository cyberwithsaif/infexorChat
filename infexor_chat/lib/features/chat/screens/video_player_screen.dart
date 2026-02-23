import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../services/media_service.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoUrl;
  final String senderName;
  final String caption;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.senderName = '',
    this.caption = '',
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;
  bool _isDownloading = false;
  CancelToken? _cancelToken;

  Future<void> _downloadVideo() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _cancelToken = CancelToken();
    });

    if (mounted) {
      _showMessage('Saving video...', duration: const Duration(seconds: 10));
    }

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'VID_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(_resolvedUrl, filePath, cancelToken: _cancelToken);
      await Gal.putVideo(filePath);

      // Tell backend we downloaded it so it can clean it up after 1 day
      ref.read(mediaServiceProvider).markDownloaded(widget.videoUrl);

      if (mounted) {
        _showMessage('Video saved to gallery');
      }
    } catch (e) {
      if (mounted) {
        if (CancelToken.isCancel(e as DioException)) {
          _showMessage('Download cancelled');
        } else {
          _showMessage('Failed to save video to gallery');
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

  Future<void> _shareVideo() async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'share_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(_resolvedUrl, filePath);

      await Share.shareXFiles([
        XFile(filePath),
      ], text: widget.caption.isNotEmpty ? widget.caption : null);
    } catch (e) {
      if (mounted) {
        _showMessage('Failed to share video');
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

  String get _resolvedUrl {
    if (widget.videoUrl.startsWith('http')) return widget.videoUrl;
    final serverRoot = ApiEndpoints.baseUrl.replaceAll('/api', '');
    return '$serverRoot${widget.videoUrl}';
  }

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(_resolvedUrl))
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
      });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
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
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareVideo,
            tooltip: 'Share',
          ),
          // Download / Cancel button
          IconButton(
            icon: _isDownloading
                ? const Icon(Icons.close, color: Colors.white)
                : const Icon(Icons.download, color: Colors.white),
            onPressed: _isDownloading ? _cancelDownload : _downloadVideo,
            tooltip: _isDownloading ? 'Cancel Download' : 'Download',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Video
                  if (_initialized)
                    Center(
                      child: Hero(
                        tag: widget.videoUrl,
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentBlue,
                        strokeWidth: 2,
                      ),
                    ),
                  // Play/Pause overlay
                  if (_showControls && _initialized)
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Progress bar
          if (_initialized)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    _formatDuration(_controller.value.position),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        trackHeight: 2,
                        activeTrackColor: AppColors.accentBlue,
                        inactiveTrackColor: AppColors.border,
                        thumbColor: AppColors.accentBlue,
                        overlayColor: AppColors.accentBlue.withValues(
                          alpha: 0.2,
                        ),
                      ),
                      child: Slider(
                        value: _controller.value.duration.inMilliseconds > 0
                            ? _controller.value.position.inMilliseconds /
                                  _controller.value.duration.inMilliseconds
                            : 0.0,
                        onChanged: (value) {
                          final duration = _controller.value.duration;
                          _controller.seekTo(duration * value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_controller.value.duration),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          // Caption
          if (widget.caption.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                8 + MediaQuery.of(context).padding.bottom,
              ),
              color: Colors.black,
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
