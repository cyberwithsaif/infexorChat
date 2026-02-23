import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/utils/animated_page_route.dart';
import '../services/media_service.dart';
import 'image_viewer_screen.dart';
import 'video_player_screen.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;

  const MediaGalleryScreen({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _mediaItems = [];
  List<Map<String, dynamic>> _docItems = [];
  List<Map<String, dynamic>> _linkItems = [];
  bool _isLoadingMedia = false;
  bool _isLoadingDocs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      if (_tabController.index == 0 && _mediaItems.isEmpty) _loadMedia();
      if (_tabController.index == 1 && _docItems.isEmpty) _loadDocs();
      if (_tabController.index == 2 && _linkItems.isEmpty) _extractLinks();
    });
    _loadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${ApiEndpoints.baseUrl.replaceAll('/api', '')}$url';
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoadingMedia = true);
    try {
      final result = await ref
          .read(mediaServiceProvider)
          .getChatMedia(widget.chatId, type: 'media');
      setState(() {
        _mediaItems = List<Map<String, dynamic>>.from(result['messages'] ?? []);
        _isLoadingMedia = false;
      });
    } catch (_) {
      setState(() => _isLoadingMedia = false);
    }
  }

  Future<void> _loadDocs() async {
    setState(() => _isLoadingDocs = true);
    try {
      final result = await ref
          .read(mediaServiceProvider)
          .getChatMedia(widget.chatId, type: 'docs');
      setState(() {
        _docItems = List<Map<String, dynamic>>.from(result['messages'] ?? []);
        _isLoadingDocs = false;
      });
    } catch (_) {
      setState(() => _isLoadingDocs = false);
    }
  }

  void _extractLinks() {
    // Extract links from already loaded messages — this is a simplified approach
    // In a full implementation, you'd have a backend API for this
    setState(() => _linkItems = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chatName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentBlue,
          labelColor: AppColors.accentBlue,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Media'),
            Tab(text: 'Docs'),
            Tab(text: 'Links'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMediaGrid(), _buildDocsList(), _buildLinksList()],
      ),
    );
  }

  Widget _buildMediaGrid() {
    if (_isLoadingMedia) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentBlue),
      );
    }
    if (_mediaItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              'No media yet',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _mediaItems.length,
      itemBuilder: (context, index) {
        final item = _mediaItems[index];
        final type = item['type'] ?? 'image';
        final media = item['media'] as Map<String, dynamic>? ?? {};
        final url = _resolveUrl(media['thumbnail'] ?? media['url'] ?? '');

        return GestureDetector(
          onTap: () {
            if (type == 'video') {
              Navigator.push(
                context,
                ScaleFadePageRoute(
                  builder: (_) => VideoPlayerScreen(
                    videoUrl: _resolveUrl(media['url'] ?? ''),
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                ScaleFadePageRoute(
                  builder: (_) => ImageViewerScreen(
                    imageUrl: _resolveUrl(media['url'] ?? ''),
                  ),
                ),
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.bgCard,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentBlue,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.bgCard,
                  child: const Icon(
                    Icons.broken_image,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (type == 'video')
                const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocsList() {
    if (_isLoadingDocs) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentBlue),
      );
    }
    if (_docItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              'No documents yet',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _docItems.length,
      itemBuilder: (context, index) {
        final item = _docItems[index];
        final media = item['media'] as Map<String, dynamic>? ?? {};
        final fileName = media['fileName'] ?? 'Document';
        final size = media['size'] ?? 0;
        final createdAt = item['createdAt'] ?? '';

        String dateStr = '';
        try {
          dateStr = DateFormat(
            'MMM d, yyyy',
          ).format(DateTime.parse(createdAt).toLocal());
        } catch (_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insert_drive_file_rounded,
                  color: AppColors.accentBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatFileSize(size)} • $dateStr',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinksList() {
    if (_linkItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No links yet',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _linkItems.length,
      itemBuilder: (context, index) {
        final item = _linkItems[index];
        return ListTile(
          leading: const Icon(Icons.link, color: AppColors.accentBlue),
          title: Text(
            item['content'] ?? '',
            style: const TextStyle(
              color: AppColors.accentBlue,
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  String _formatFileSize(dynamic bytes) {
    final b = (bytes is int) ? bytes : int.tryParse('$bytes') ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
