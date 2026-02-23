import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../chat/services/media_service.dart';
import '../../chat/screens/image_viewer_screen.dart';
import '../../chat/screens/video_player_screen.dart';

class AllMediaGalleryScreen extends ConsumerStatefulWidget {
  const AllMediaGalleryScreen({super.key});

  @override
  ConsumerState<AllMediaGalleryScreen> createState() =>
      _AllMediaGalleryScreenState();
}

class _AllMediaGalleryScreenState extends ConsumerState<AllMediaGalleryScreen> {
  List<Map<String, dynamic>> _mediaItems = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${ApiEndpoints.baseUrl.replaceAll('/api', '')}$url';
  }

  Future<void> _loadMedia({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _page = 1;
        _hasMore = true;
      }
    });

    try {
      final result = await ref
          .read(mediaServiceProvider)
          .getAllMedia(page: _page, limit: 30);

      final List newItems = result['media'] ?? [];

      setState(() {
        if (refresh) {
          _mediaItems = List<Map<String, dynamic>>.from(newItems);
        } else {
          _mediaItems.addAll(List<Map<String, dynamic>>.from(newItems));
        }
        _isLoading = false;
        _hasMore = result['hasMore'] == true;
        _page++;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: const Text(
          'Infexor Gallery',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _buildGrid(),
    );
  }

  Widget _buildGrid() {
    if (_isLoading && _mediaItems.isEmpty) {
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
              'No media found',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoading &&
            _hasMore &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
          _loadMedia();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => _loadMedia(refresh: true),
        color: AppColors.accentBlue,
        child: GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: _mediaItems.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _mediaItems.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentBlue,
                  ),
                ),
              );
            }

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
        ),
      ),
    );
  }
}
