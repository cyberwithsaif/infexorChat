import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../services/media_service.dart';

/// Resolves media URL — prepends base URL if relative path
String _resolveUrl(String url) {
  if (url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  // Strip /api from base URL to get server root
  final serverRoot = ApiEndpoints.baseUrl.replaceAll('/api', '');
  return '$serverRoot$url';
}

/// Custom CacheManager configured specifically for GIFs
/// Keeps GIFs cached longer with a higher capacity to avoid redownloading
final CacheManager gifCacheManager = CacheManager(
  Config(
    'gif_cache_keys',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 200,
  ),
);

/// Image message bubble
class ImageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onTap;

  const ImageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
  });

  @override
  State<ImageBubble> createState() => _ImageBubbleState();
}

class _ImageBubbleState extends State<ImageBubble> {
  bool _isCancelled = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final media = widget.message['media'] ?? {};
    final url = _resolveUrl(media['url'] ?? '');
    final thumbnail = _resolveUrl(media['thumbnail'] ?? '');
    final caption = widget.message['content'] ?? '';
    final createdAt = widget.message['createdAt'] ?? '';
    final status = widget.message['status'] ?? 'sent';
    final fileSize = media['size'];
    final sizeStr = fileSize != null ? _formatFileSize(fileSize) : '';

    String time = '';
    try {
      time = DateFormat.jm().format(DateTime.parse(createdAt).toLocal());
    } catch (_) {}

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.70,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: widget.isMe ? AppColors.msgSentBg : AppColors.msgReceivedBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
              bottomRight: Radius.circular(widget.isMe ? 4 : 16),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message['replyTo'] != null)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ReplyPreview(
                    replyTo: widget.message['replyTo'],
                    isMe: widget.isMe,
                  ),
                ),
              // Image - constrained height for fixed box preview
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 280,
                    minHeight: 120,
                  ),
                  child: Hero(
                    tag:
                        (widget.message['media']?['url']
                                        ?.toString()
                                        .isNotEmpty ==
                                    true
                                ? widget.message['media']['url']
                                : widget.message['media']?['thumbnail'])
                            ?.toString() ??
                        '',
                    child: _isCancelled
                        ? GestureDetector(
                            onTap: () => setState(() => _isCancelled = false),
                            child: Container(
                              height: 200,
                              color: AppColors.bgHover,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.image,
                                    color: subtitleColor.withOpacity(0.5),
                                    size: 64,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.download,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Retry',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: url.isNotEmpty ? url : thumbnail,
                            width: double.infinity,
                            cacheManager: gifCacheManager,
                            fit: BoxFit.cover,
                            progressIndicatorBuilder: (context, url, progress) {
                              return Container(
                                height: 200,
                                color: AppColors.bgHover,
                                child: Center(
                                  child: DownloadPercentageIndicator(
                                    progress: progress.progress,
                                    onCancel: () =>
                                        setState(() => _isCancelled = true),
                                  ),
                                ),
                              );
                            },
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: AppColors.bgHover,
                              child: Icon(
                                Icons.broken_image,
                                color: subtitleColor,
                                size: 40,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              // Caption + time
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          caption,
                          style: TextStyle(fontSize: 14, color: textColor),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(fontSize: 11, color: subtitleColor),
                        ),
                        if (sizeStr.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            sizeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                        if (widget.isMe) ...[
                          const SizedBox(width: 3),
                          _StatusIcon(status: status),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Video message bubble
class VideoBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onTap;

  const VideoBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
  });

  @override
  State<VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<VideoBubble> {
  bool _isCancelled = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final media = widget.message['media'] ?? {};
    final thumbnail = _resolveUrl(media['thumbnail'] ?? '');
    final duration = media['duration'] ?? 0;
    final caption = widget.message['content'] ?? '';
    final createdAt = widget.message['createdAt'] ?? '';
    final status = widget.message['status'] ?? 'sent';
    final fileSize = media['size'];
    final videoSizeStr = fileSize != null ? _formatFileSize(fileSize) : '';

    String time = '';
    try {
      time = DateFormat.jm().format(DateTime.parse(createdAt).toLocal());
    } catch (_) {}

    String durationStr = '';
    if (duration > 0) {
      final mins = (duration ~/ 60).toString().padLeft(2, '0');
      final secs = (duration % 60).toString().padLeft(2, '0');
      durationStr = '$mins:$secs';
    }

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.70,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: widget.isMe ? AppColors.msgSentBg : AppColors.msgReceivedBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
              bottomRight: Radius.circular(widget.isMe ? 4 : 16),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message['replyTo'] != null)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ReplyPreview(
                    replyTo: widget.message['replyTo'],
                    isMe: widget.isMe,
                  ),
                ),
              // Thumbnail with play overlay
              Hero(
                tag: widget.message['media']?['url']?.toString() ?? '',
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isCancelled)
                      GestureDetector(
                        onTap: () => setState(() => _isCancelled = false),
                        child: Container(
                          height: 200,
                          color: AppColors.bgHover,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.videocam,
                                color: subtitleColor.withValues(alpha: 0.5),
                                size: 64,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.download,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Retry',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (thumbnail.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: thumbnail,
                        width: double.infinity,
                        height: 200,
                        cacheManager: gifCacheManager,
                        fit: BoxFit.cover,
                        progressIndicatorBuilder: (context, url, progress) {
                          return Container(
                            height: 200,
                            color: AppColors.bgHover,
                            child: Center(
                              child: DownloadPercentageIndicator(
                                progress: progress.progress,
                                onCancel: () =>
                                    setState(() => _isCancelled = true),
                              ),
                            ),
                          );
                        },
                        errorWidget: (context, url, error) =>
                            Container(height: 200, color: AppColors.bgHover),
                      )
                    else
                      Container(height: 200, color: AppColors.bgHover),
                    // Play button
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    // Duration badge
                    if (durationStr.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            durationStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Caption + time
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          caption,
                          style: TextStyle(fontSize: 14, color: textColor),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(fontSize: 11, color: subtitleColor),
                        ),
                        if (videoSizeStr.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            videoSizeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                        if (widget.isMe) ...[
                          const SizedBox(width: 3),
                          _StatusIcon(status: status),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Voice/Audio message bubble
class VoiceBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isPlaying;
  final double progress;
  final VoidCallback? onPlayPause;

  const VoiceBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isPlaying = false,
    this.progress = 0.0,
    this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final media = message['media'] ?? {};
    final duration = media['duration'] ?? 0;
    final createdAt = message['createdAt'] ?? '';
    final status = message['status'] ?? 'sent';

    String time = '';
    try {
      time = DateFormat.jm().format(DateTime.parse(createdAt).toLocal());
    } catch (_) {}

    String durationStr = '0:00';
    if (duration > 0) {
      final mins = duration ~/ 60;
      final secs = (duration % 60).toString().padLeft(2, '0');
      durationStr = '$mins:$secs';
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.70,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 6),
        decoration: BoxDecoration(
          color: isMe ? AppColors.msgSentBg : AppColors.msgReceivedBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message['replyTo'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ReplyPreview(replyTo: message['replyTo'], isMe: isMe),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play/Pause button
                GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Waveform / progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accentBlue,
                          ),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        durationStr,
                        style: TextStyle(fontSize: 11, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Time + status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(fontSize: 11, color: subtitleColor),
                ),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  _StatusIcon(status: status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Document message bubble
class DocumentBubble extends ConsumerStatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onTap;

  const DocumentBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
  });

  @override
  ConsumerState<DocumentBubble> createState() => _DocumentBubbleState();
}

class _DocumentBubbleState extends ConsumerState<DocumentBubble> {
  bool _isDownloading = false;
  double? _downloadProgress;
  CancelToken? _cancelToken;

  Future<void> _downloadDocument(String url, String fileName) async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _cancelToken = CancelToken();
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final resolvedUrl = _resolveUrl(url);

      await Dio().download(
        resolvedUrl,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      ref.read(mediaServiceProvider).markDownloaded(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (CancelToken.isCancel(e as DioException)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download cancelled'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to download document'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final media = widget.message['media'] ?? {};
    final url = media['url'] ?? '';
    final fileName = media['fileName'] ?? 'Document';
    final size = media['size'] ?? 0;
    final caption = widget.message['content'] ?? '';
    final createdAt = widget.message['createdAt'] ?? '';
    final status = widget.message['status'] ?? 'sent';

    String time = '';
    try {
      time = DateFormat.jm().format(DateTime.parse(createdAt).toLocal());
    } catch (_) {}

    String sizeStr = _formatFileSize(size);

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.70,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          decoration: BoxDecoration(
            color: widget.isMe ? AppColors.msgSentBg : AppColors.msgReceivedBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
              bottomRight: Radius.circular(widget.isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message['replyTo'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ReplyPreview(
                    replyTo: widget.message['replyTo'],
                    isMe: widget.isMe,
                  ),
                ),
              // Document info row
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.insert_drive_file_rounded,
                      color: AppColors.accentPurple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sizeStr,
                          style: TextStyle(fontSize: 12, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                  if (_isDownloading)
                    GestureDetector(
                      onTap: _cancelDownload,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _downloadProgress,
                            strokeWidth: 2,
                            color: AppColors.accentBlue,
                          ),
                          const Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.accentBlue,
                          ),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: url.isNotEmpty
                          ? () => _downloadDocument(url, fileName)
                          : null,
                      child: const Icon(
                        Icons.download_rounded,
                        color: AppColors.accentBlue,
                        size: 24,
                      ),
                    ),
                ],
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(caption, style: TextStyle(fontSize: 14, color: textColor)),
              ],
              const SizedBox(height: 4),
              // Time + status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                  if (sizeStr.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      sizeStr,
                      style: TextStyle(fontSize: 11, color: subtitleColor),
                    ),
                  ],
                  if (widget.isMe) ...[
                    const SizedBox(width: 3),
                    _StatusIcon(status: status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Location message bubble
class LocationBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onTap;

  const LocationBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final location = message['location'] ?? {};
    final lat = location['latitude'] ?? 0.0;
    final lng = location['longitude'] ?? 0.0;
    final address = location['address'] ?? '';
    final createdAt = message['createdAt'] ?? '';
    final status = message['status'] ?? 'sent';

    String time = '';
    try {
      time = DateFormat.jm().format(DateTime.parse(createdAt).toLocal());
    } catch (_) {}

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.70,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isMe ? AppColors.msgSentBg : AppColors.msgReceivedBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message['replyTo'] != null)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: ReplyPreview(replyTo: message['replyTo'], isMe: isMe),
                ),
              // Map placeholder
              Container(
                height: 150,
                width: double.infinity,
                color: AppColors.bgHover,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.danger,
                      size: 36,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (address.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: textColor),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 13,
                          color: AppColors.accentBlue,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Open in Maps',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accentBlue,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          time,
                          style: TextStyle(fontSize: 11, color: subtitleColor),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          _StatusIcon(status: status),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contact share bubble
class ContactBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onTap;

  const ContactBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final contact = message['contactShare'] ?? {};
    final name = contact['name'] ?? 'Unknown';
    final phone = contact['phone'] ?? '';
    final createdAt = message['createdAt'] ?? '';
    final status = message['status'] ?? 'sent';

    String time = '';
    try {
      time = DateFormat.jm().format(DateTime.parse(createdAt).toLocal());
    } catch (_) {}

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.70,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          decoration: BoxDecoration(
            color: isMe ? AppColors.msgSentBg : AppColors.msgReceivedBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message['replyTo'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ReplyPreview(replyTo: message['replyTo'], isMe: isMe),
                ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.bgHover,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: subtitleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.border, height: 16),
              Row(
                children: [
                  const Text(
                    'View contact',
                    style: TextStyle(fontSize: 13, color: AppColors.accentBlue),
                  ),
                  const Spacer(),
                  Text(
                    time,
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    _StatusIcon(status: status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status icon widget
class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    switch (status) {
      case 'read':
        return const Icon(Icons.done_all, size: 14, color: AppColors.checkRead);
      case 'delivered':
        return Icon(Icons.done_all, size: 14, color: subtitleColor);
      case 'sent':
        return Icon(Icons.done, size: 14, color: subtitleColor);
      default:
        return Icon(Icons.access_time, size: 12, color: subtitleColor);
    }
  }
}

/// Format file size
String _formatFileSize(dynamic bytes) {
  final size = (bytes is int) ? bytes : 0;
  if (size < 1024) return '$size B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  if (size < 1024 * 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class ReplyPreview extends StatelessWidget {
  final Map<String, dynamic>? replyTo;
  final bool isMe;

  const ReplyPreview({super.key, this.replyTo, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;

    if (replyTo == null) return const SizedBox.shrink();

    final content = replyTo!['content'] ?? 'Media';
    final sender = replyTo!['senderId'];
    final senderName = (sender is Map)
        ? (sender['name'] ?? 'Unknown')
        : 'Unknown';
    final type = replyTo!['type'] ?? 'text';

    IconData? icon;
    if (type == 'image') {
      icon = Icons.image;
    } else if (type == 'video')
      icon = Icons.videocam;
    else if (type == 'voice' || type == 'audio')
      icon = Icons.mic;
    else if (type == 'document')
      icon = Icons.insert_drive_file;
    else if (type == 'location')
      icon = Icons.location_on;
    else if (type == 'contact')
      icon = Icons.person;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.accentBlue, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.blue[300] : AppColors.accentBlue,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: subtitleColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  content.toString().isEmpty ? type : content.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A smooth percentage text indicator for media downloading
class DownloadPercentageIndicator extends StatelessWidget {
  final double? progress;
  final Color color;
  final VoidCallback? onCancel;

  const DownloadPercentageIndicator({
    super.key,
    this.progress,
    this.color = Colors.white,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (progress == null) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accentBlue,
        ),
      );
    }

    final percent = (progress! * 100).toInt().clamp(0, 100);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: onCancel,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    onCancel != null ? Icons.close : Icons.download,
                    color: color,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
