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

  // Selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

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
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: AppColors.accentBlue,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              ),
              title: Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      if (_selectedIds.length == _mediaItems.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.addAll(
                          _mediaItems.map((item) => item['_id'].toString()),
                        );
                      }
                    });
                  },
                ),
                if (_selectedIds.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: _deleteSelectedItems,
                  ),
              ],
            )
          : AppBar(
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
            final id = item['_id']?.toString() ?? '';
            final type = item['type'] ?? 'image';
            final media = item['media'] as Map<String, dynamic>? ?? {};
            final url = _resolveUrl(media['thumbnail'] ?? media['url'] ?? '');
            final isSelected = _selectedIds.contains(id);

            return GestureDetector(
              onLongPress: () => _toggleSelection(id),
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(id);
                  return;
                }
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
                  if (isSelected)
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle,
                          color: AppColors.accentBlue,
                          size: 32,
                        ),
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

  void _toggleSelection(String id) {
    if (id.isEmpty) return;
    setState(() {
      _isSelectionMode = true;
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedItems() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text(
          'Delete Media',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to logically delete ${_selectedIds.length} media item(s)? This will free up storage for you but will not delete it for the recipient.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final mediaService = ref.read(mediaServiceProvider);
    final idsToDelete = _selectedIds.toList();

    try {
      await mediaService.deleteBulkMedia(idsToDelete);

      if (!mounted) return;
      setState(() {
        _mediaItems.removeWhere(
          (item) => idsToDelete.contains(item['_id'].toString()),
        );
        _selectedIds.clear();
        _isSelectionMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media items deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete media items')),
      );
    }
  }
}
