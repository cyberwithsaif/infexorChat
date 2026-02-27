import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';
import '../chat/services/media_service.dart';
import 'status_provider.dart';

class CreateStatusScreen extends ConsumerStatefulWidget {
  final ImageSource? initialSource;
  const CreateStatusScreen({super.key, this.initialSource});

  @override
  ConsumerState<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends ConsumerState<CreateStatusScreen> {
  final _textController = TextEditingController();
  final _captionController = TextEditingController();
  bool _isPosting = false;
  String? _imagePath;
  double _uploadProgress = 0;
  bool _pickingImage = false; // prevents text mode flash
  bool _showEmoji = false;
  VideoPlayerController? _videoController;

  bool _isVideoFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv');
  }

  int _colorIndex = 0;
  static const _bgColors = [
    '#075E54', // WhatsApp dark green
    '#128C7E', // WhatsApp teal
    '#25D366', // WhatsApp green
    '#34B7F1', // WhatsApp blue
    '#ECE5DD', // WhatsApp beige
    '#FF6B6B', // Red
    '#4ECDC4', // Cyan
    '#45B7D1', // Sky blue
    '#96CEB4', // Sage
    '#FFEAA7', // Yellow
    '#DDA0DD', // Plum
    '#FF7675', // Salmon
    '#6C5CE7', // Purple
    '#FD79A8', // Pink
    '#2D3436', // Dark grey
  ];

  // Common emojis grouped by category
  static const _emojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '😚',
    '😙',
    '🥲',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🫡',
    '🤐',
    '🤨',
    '😐',
    '😑',
    '😶',
    '🫥',
    '😏',
    '😒',
    '🙄',
    '😬',
    '🤥',
    '😌',
    '😔',
    '😪',
    '🤤',
    '😴',
    '😷',
    '🤒',
    '🤕',
    '🤢',
    '🤮',
    '🥵',
    '🥶',
    '🥴',
    '😵',
    '🤯',
    '🤠',
    '🥳',
    '🥸',
    '😎',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '💔',
    '💕',
    '💖',
    '💗',
    '💘',
    '💝',
    '💞',
    '💟',
    '❣️',
    '💌',
    '🫶',
    '👍',
    '👎',
    '👊',
    '✊',
    '🤛',
    '🤜',
    '👏',
    '🙌',
    '👐',
    '🤲',
    '🤝',
    '🙏',
    '✌️',
    '🤞',
    '🤟',
    '🤘',
    '🤙',
    '👈',
    '👉',
    '👆',
    '🔥',
    '⭐',
    '🌟',
    '💫',
    '✨',
    '⚡',
    '💥',
    '💢',
    '💦',
    '💨',
    '🌈',
    '☀️',
    '🌤️',
    '🌙',
    '🌸',
    '🌺',
    '🌻',
    '🌹',
    '🎉',
    '🎊',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSource != null) {
      _pickingImage = true;
      // Defer to let the screen render first
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImage(widget.initialSource!);
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _textController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    XFile? picked;

    if (source == ImageSource.gallery) {
      // Pick either image or video from gallery
      picked = await picker.pickMedia(
        imageQuality: 80,
        requestFullMetadata: false,
      );
    } else {
      picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
    }

    if (picked != null) {
      if (mounted) {
        setState(() {
          _imagePath = picked!.path;
          _pickingImage = false;
        });

        // Check if video and initialize player
        final isVideo = _isVideoFile(_imagePath!);

        if (isVideo) {
          _videoController = VideoPlayerController.file(File(_imagePath!))
            ..initialize().then((_) {
              if (mounted) {
                setState(() {});
                _videoController!.play();
                _videoController!.setLooping(true);
              }
            });
        }
      }
    } else {
      // User cancelled
      if (mounted) {
        if (_imagePath == null) {
          Navigator.pop(context);
        } else {
          setState(() => _pickingImage = false);
        }
      }
    }
  }

  Future<void> _postTextStatus() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    final success = await ref
        .read(statusProvider.notifier)
        .createTextStatus(text, _bgColors[_colorIndex]);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to post status')));
      }
    }
  }

  Future<void> _postImageStatus() async {
    if (_imagePath == null) return;

    setState(() {
      _isPosting = true;
      _uploadProgress = 0;
    });

    try {
      final mediaService = ref.read(mediaServiceProvider);
      final isVideo = _isVideoFile(_imagePath!);

      Map<String, dynamic> uploadResult;

      if (isVideo) {
        uploadResult = await mediaService.uploadVideo(
          _imagePath!,
          onSendProgress: (sent, total) {
            if (total > 0 && mounted) {
              setState(() => _uploadProgress = sent / total);
            }
          },
        );
      } else {
        uploadResult = await mediaService.uploadImage(
          _imagePath!,
          onSendProgress: (sent, total) {
            if (total > 0 && mounted) {
              setState(() => _uploadProgress = sent / total);
            }
          },
        );
      }

      final type = isVideo ? 'video' : 'image';

      final success = await ref
          .read(statusProvider.notifier)
          .createMediaStatus(
            uploadResult,
            _captionController.text.trim(),
            type,
          );

      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
        } else {
          throw Exception('Failed to create status');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
      }
    }
  }

  void _insertEmoji(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = text.replaceRange(
      selection.start >= 0 ? selection.start : text.length,
      selection.end >= 0 ? selection.end : text.length,
      emoji,
    );
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset:
            (selection.start >= 0 ? selection.start : text.length) +
            emoji.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while image picker is open (prevents text mode flash)
    if (_pickingImage && _imagePath == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_imagePath != null) {
      return _buildImageMode();
    }
    return _buildTextMode();
  }

  Widget _buildTextMode() {
    final bgColor = Color(
      int.parse(_bgColors[_colorIndex].replaceFirst('#', '0xFF')),
    );
    final isLight = bgColor.computeLuminance() > 0.5;
    final textColor = isLight ? Colors.black87 : Colors.white;
    final hintColor = isLight ? Colors.black38 : Colors.white54;

    return Scaffold(
      // Use a builder to wrap the body with color
      body: Container(
        // Explicit container color — guarantees background regardless of theme
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              // Custom top bar (not using AppBar to avoid theme issues)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    if (!_isPosting)
                      IconButton(
                        icon: Icon(
                          _showEmoji
                              ? Icons.keyboard
                              : Icons.emoji_emotions_outlined,
                          color: textColor,
                        ),
                        onPressed: () {
                          setState(() => _showEmoji = !_showEmoji);
                          if (_showEmoji) {
                            FocusScope.of(context).unfocus();
                          }
                        },
                      ),
                    if (!_isPosting)
                      IconButton(
                        icon: Icon(Icons.palette, color: textColor),
                        onPressed: () {
                          setState(() {
                            _colorIndex = (_colorIndex + 1) % _bgColors.length;
                          });
                        },
                      ),
                  ],
                ),
              ),
              // Text input area
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_showEmoji) {
                      setState(() => _showEmoji = false);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: TextField(
                        controller: _textController,
                        autofocus: !_showEmoji,
                        maxLines: null,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        cursorColor: textColor,
                        decoration: InputDecoration(
                          hintText: 'Type a status',
                          hintStyle: TextStyle(color: hintColor, fontSize: 28),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                        onTap: () {
                          if (_showEmoji) {
                            setState(() => _showEmoji = false);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Emoji picker
              if (_showEmoji)
                Container(
                  height: 280,
                  color: isLight ? Colors.white : Colors.black87,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemCount: _emojis.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _insertEmoji(_emojis[index]),
                        child: Center(
                          child: Text(
                            _emojis[index],
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isPosting
          ? const FloatingActionButton(
              onPressed: null,
              backgroundColor: AppColors.accentBlue,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          : FloatingActionButton(
              onPressed: _postTextStatus,
              backgroundColor: AppColors.accentBlue,
              child: const Icon(Icons.send, color: Colors.white),
            ),
    );
  }

  Widget _buildImageMode() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isPosting)
            IconButton(
              icon: const Icon(Icons.photo_library, color: Colors.white),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _videoController != null
                  ? (_videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : const CircularProgressIndicator(color: Colors.white))
                  : Image.file(File(_imagePath!), fit: BoxFit.contain),
            ),
          ),
          if (_isPosting)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                    backgroundColor: Colors.white24,
                    color: AppColors.accentBlue,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Posting… ${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          if (!_isPosting)
            Container(
              color: Colors.black87,
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                8,
                8 + MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    onPressed: _postImageStatus,
                    backgroundColor: AppColors.accentBlue,
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
