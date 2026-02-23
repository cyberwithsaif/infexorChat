import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/utils/url_utils.dart';
import '../auth/providers/auth_provider.dart';
import 'status_provider.dart';

class ViewStatusScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> statuses;
  final int initialIndex;

  const ViewStatusScreen({
    super.key,
    required this.user,
    required this.statuses,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<ViewStatusScreen> createState() => _ViewStatusScreenState();
}

class _ViewStatusScreenState extends ConsumerState<ViewStatusScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  static const _statusDuration = Duration(seconds: 5);
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressController = AnimationController(
      vsync: this,
      duration: _statusDuration,
    );
    // Single listener — never stacked
    _progressController.addStatusListener(_onProgressDone);
    _progressController.forward();
    _markViewed();
  }

  @override
  void dispose() {
    _progressController.removeStatusListener(_onProgressDone);
    _progressController.dispose();
    super.dispose();
  }

  void _onProgressDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _nextStatus();
    }
  }

  void _restartProgress() {
    _progressController.reset();
    _progressController.forward();
  }

  void _nextStatus() {
    if (!mounted || _isPopping) return;
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() => _currentIndex++);
      _markViewed();
      _restartProgress();
    } else {
      _isPopping = true;
      _progressController.stop();
      Navigator.of(context).pop();
    }
  }

  void _prevStatus() {
    if (!mounted || _isPopping) return;
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _markViewed();
      _restartProgress();
    } else {
      // Already at first status, just restart the timer
      _restartProgress();
    }
  }

  void _markViewed() {
    final status = widget.statuses[_currentIndex];
    final id = status['_id']?.toString();
    if (id != null) {
      ref.read(statusProvider.notifier).viewStatus(id);
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }

  void _showViewers(List viewers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Viewed by ${viewers.length}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: viewers.isEmpty
                  ? const Center(
                      child: Text(
                        'No views yet',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: viewers.length,
                      itemBuilder: (context, index) {
                        final viewer = viewers[index];
                        final user = viewer['userId'] is Map
                            ? viewer['userId']
                            : {};
                        final name = user['name'] ?? 'Unknown';
                        final avatar = UrlUtils.getFullUrl(
                          user['avatar'] ?? '',
                        );
                        final time = _formatTime(
                          viewer['viewedAt']?.toString(),
                        );
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: avatar.isNotEmpty
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            child: avatar.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(color: Colors.black87),
                          ),
                          trailing: Text(
                            time,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted && !_isPopping) {
        _progressController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.statuses[_currentIndex];
    final isText = status['type'] == 'text';
    final content = status['content'] ?? '';
    final bgColor = isText
        ? Color(
            int.parse(
              (status['backgroundColor'] ?? '#075E54').toString().replaceFirst(
                '#',
                '0xFF',
              ),
            ),
          )
        : Colors.black;
    final isLight = bgColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black : Colors.white;

    final currentUser = ref.watch(authProvider).user;
    final isMine = widget.user['_id'] == currentUser?['_id'];

    final userName = isMine ? 'Me' : (widget.user['name'] ?? 'Unknown');
    final userAvatar = UrlUtils.getFullUrl(widget.user['avatar'] ?? '');
    final timeStr = _formatTime(status['createdAt']?.toString());

    final mediaUrl = status['media'] is Map
        ? UrlUtils.getFullUrl(status['media']['url'] ?? '')
        : '';

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth * 0.3) {
            _prevStatus();
          } else {
            _nextStatus();
          }
        },
        onLongPressStart: (_) {
          // Pause on long press
          _progressController.stop();
        },
        onLongPressEnd: (_) {
          // Resume on release
          if (mounted && !_isPopping) {
            _progressController.forward();
          }
        },
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) {
            _isPopping = true;
            _progressController.stop();
            Navigator.of(context).pop();
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              // Status content — fill whole screen for tap targets
              Positioned.fill(
                child: isText
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            content,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : mediaUrl.isNotEmpty
                    ? Center(
                        child: CachedNetworkImage(
                          imageUrl: mediaUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (_, url, err) => const Center(
                            child: Icon(
                              Icons.error,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.expand(),
              ),

              // Image caption
              if (!isText && content.isNotEmpty)
                Positioned(
                  bottom: isMine
                      ? 80
                      : 24, // Leave space for viewers icon if mine
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      content,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),

              // Viewers (only for my status)
              if (isMine)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      _progressController.stop();
                      _showViewers(status['viewers'] as List? ?? []);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.white,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.remove_red_eye,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(status['viewers'] as List?)?.length ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Top bar: progress + user info
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Progress bars
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: List.generate(
                          widget.statuses.length,
                          (i) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: i == _currentIndex
                                    ? AnimatedBuilder(
                                        animation: _progressController,
                                        builder: (_, child) =>
                                            LinearProgressIndicator(
                                              value: _progressController.value,
                                              backgroundColor: Colors.white30,
                                              color: Colors.white,
                                              minHeight: 2.5,
                                            ),
                                      )
                                    : LinearProgressIndicator(
                                        value: i < _currentIndex ? 1.0 : 0.0,
                                        backgroundColor: Colors.white30,
                                        color: Colors.white,
                                        minHeight: 2.5,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // User row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            backgroundImage: userAvatar.isNotEmpty
                                ? CachedNetworkImageProvider(userAvatar)
                                : null,
                            child: userAvatar.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMine)
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                _progressController.stop();
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete status update?'),
                                    content: const Text(
                                      'It will be deleted for everyone who received it.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  _isPopping = true;
                                  await ref
                                      .read(statusProvider.notifier)
                                      .deleteStatus(status['_id']);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Status deleted'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  }
                                } else {
                                  if (mounted && !_isPopping) {
                                    _progressController.forward();
                                  }
                                }
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              _isPopping = true;
                              _progressController.stop();
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
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
