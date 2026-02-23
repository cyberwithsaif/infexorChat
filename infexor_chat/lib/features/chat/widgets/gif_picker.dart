import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';

/// GIF picker bottom sheet using Tenor API (free tier).
///
/// Shows trending GIFs by default, supports search.
/// Returns a GIF URL when the user taps on a GIF.
class GifPicker extends StatefulWidget {
  final void Function(String gifUrl, String previewUrl) onGifSelected;
  final bool isInline;
  final ScrollController? scrollController;

  const GifPicker({
    super.key,
    required this.onGifSelected,
    this.isInline = false,
    this.scrollController,
  });

  @override
  State<GifPicker> createState() => _GifPickerState();
}

class _GifPickerState extends State<GifPicker> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _gifs = [];
  bool _isLoading = false;

  // Tenor API v2 key (free, limited usage — replace with your own for production)
  static const _tenorApiKey = 'AIzaSyAyimkuYQYF_FXVALexPuGQctUWRURdCYQ';

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
        'https://tenor.googleapis.com/v2/featured?key=$_tenorApiKey&limit=30&media_filter=gif,tinygif',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _gifs = List<Map<String, dynamic>>.from(data['results'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadTrending();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
        'https://tenor.googleapis.com/v2/search?q=${Uri.encodeComponent(query)}&key=$_tenorApiKey&limit=30&media_filter=gif,tinygif',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _gifs = List<Map<String, dynamic>>.from(data['results'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String? _getGifUrl(Map<String, dynamic> gif) {
    final mediaFormats = gif['media_formats'] as Map<String, dynamic>?;
    if (mediaFormats == null) return null;
    final gifFormat = mediaFormats['gif'] as Map<String, dynamic>?;
    return gifFormat?['url'] as String?;
  }

  String? _getPreviewUrl(Map<String, dynamic> gif) {
    final mediaFormats = gif['media_formats'] as Map<String, dynamic>?;
    if (mediaFormats == null) return null;
    final tinyGif = mediaFormats['tinygif'] as Map<String, dynamic>?;
    return tinyGif?['url'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    if (widget.isInline) {
      return Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildGrid()),
          _buildPoweredBy(),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : AppColors.bgSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: subtitleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _buildSearchBar(),
          Expanded(child: _buildGrid()),
          _buildPoweredBy(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final bgColor = theme.scaffoldBackgroundColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search GIFs…',
          hintStyle: TextStyle(color: subtitleColor),
          prefixIcon: Icon(Icons.search, color: subtitleColor),
          filled: true,
          fillColor: bgColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          isDense: true,
        ),
        onSubmitted: _search,
      ),
    );
  }

  Widget _buildGrid() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final cardColor = isDark ? AppColors.darkBgSecondary : AppColors.bgCard;

    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.accentBlue),
          )
        : _gifs.isEmpty
        ? Center(
            child: Text(
              'No GIFs found',
              style: TextStyle(color: subtitleColor),
            ),
          )
        : GridView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: _gifs.length,
            itemBuilder: (context, index) {
              final gif = _gifs[index];
              final previewUrl = _getPreviewUrl(gif);

              if (previewUrl == null) return const SizedBox.shrink();

              return GestureDetector(
                onTap: () {
                  final gifUrl = _getGifUrl(gif);
                  if (gifUrl != null) {
                    if (!widget.isInline) {
                      Navigator.pop(context);
                    }
                    widget.onGifSelected(gifUrl, previewUrl);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    previewUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: cardColor,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentBlue,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: cardColor,
                      child: Icon(Icons.broken_image, color: subtitleColor),
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildPoweredBy() {
    final theme = Theme.of(context);
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        'Powered by Tenor',
        style: TextStyle(color: subtitleColor, fontSize: 11),
      ),
    );
  }
}

void showGifPicker(
  BuildContext context, {
  required void Function(String gifUrl, String previewUrl) onGifSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => GifPicker(
        onGifSelected: onGifSelected,
        scrollController: scrollController,
      ),
    ),
  );
}
