import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/message_provider.dart';
import '../providers/chat_provider.dart';
import '../services/socket_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/media_service.dart';
import '../widgets/attachment_picker.dart';
import '../widgets/media_bubbles.dart';
import '../widgets/gif_picker.dart';
import 'image_viewer_screen.dart';
import 'video_player_screen.dart';
import 'user_profile_screen.dart';
import '../widgets/chat_background.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../../core/animations/page_transitions.dart';
import 'group_info_screen.dart';
import '../../settings/providers/wallpaper_provider.dart';
import '../../settings/screens/wallpaper_selection_screen.dart';
import 'call_screen.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../../shared/widgets/glass_morphism.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;
  final bool isOnline;
  final bool isGroup;
  final String groupId;

  const ConversationScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.chatAvatar = '',
    this.isOnline = false,
    this.isGroup = false,
    this.groupId = '',
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

/// Holds audio playback state so only the playing VoiceBubble rebuilds.
class AudioPlaybackState {
  final String? playingMessageId;
  final bool isPlaying;
  final Duration totalDuration;
  final Duration currentPosition;

  const AudioPlaybackState({
    this.playingMessageId,
    this.isPlaying = false,
    this.totalDuration = Duration.zero,
    this.currentPosition = Duration.zero,
  });

  AudioPlaybackState copyWith({
    String? playingMessageId,
    bool? isPlaying,
    Duration? totalDuration,
    Duration? currentPosition,
  }) {
    return AudioPlaybackState(
      playingMessageId: playingMessageId ?? this.playingMessageId,
      isPlaying: isPlaying ?? this.isPlaying,
      totalDuration: totalDuration ?? this.totalDuration,
      currentPosition: currentPosition ?? this.currentPosition,
    );
  }
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadingType = '';

  final _audioPlayer = AudioPlayer();
  // Use ValueNotifier so only VoiceBubble rebuilds on playback ticks
  final _audioState = ValueNotifier<AudioPlaybackState>(
    const AudioPlaybackState(),
  );
  final _audioSubs = <StreamSubscription>[];
  final Set<String> _seenMessageIds = {};
  final Set<String> _selectedMessageIds = {};
  Map<String, dynamic>? _replyMessage;

  // Block state
  bool _isBlockedByMe = false;
  bool _isBlockedByThem = false;
  String? _otherUserId;
  String _groupId = '';

  Offset? _tapPosition;
  OverlayEntry? _emojiOverlayEntry;

  void _onReply(Map<String, dynamic> msg) {
    setState(() {
      _replyMessage = msg;
    });
    // Focus input
    // The InputBar needs to handle focus request or we pass a FocusNode down?
    // _InputBar has its own FocusNode but we don't have access to it easily
    // unless we lift the state or use a controller.
    // For now, let's just set the state.
  }

  void _cancelReply() {
    setState(() {
      _replyMessage = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMessageIds.clear();
    });
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final notifService = ref.read(notificationServiceProvider);
      notifService.activeChatId = widget.chatId;
      notifService.clearCounts(widget.chatId);

      // Tell background service to clear counts too
      FlutterBackgroundService().invoke('clearChatCount', {
        'chatId': widget.chatId,
      });

      ref.read(messageProvider.notifier).openChat(widget.chatId);
      ref.read(messageProvider.notifier).initSocketListeners();

      // Check block status for 1:1 chats
      if (!widget.isGroup) {
        _checkBlockStatus();
      } else {
        // For groups, ensure we have a groupId
        _groupId = widget.groupId;
        if (_groupId.isEmpty) {
          final chats = ref.read(chatListProvider).chats;
          final currentChat = chats.firstWhere(
            (c) => c['_id'] == widget.chatId,
            orElse: () => <String, dynamic>{},
          );
          final gData = currentChat['groupId'];
          if (gData is Map) {
            _groupId = gData['_id']?.toString() ?? '';
          } else if (gData is String) {
            _groupId = gData;
          }
        }
      }
    });

    _scrollController.addListener(_onScroll);

    // Audio Player Listeners — update ValueNotifier, NOT setState
    _audioSubs.add(
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          _audioState.value = _audioState.value.copyWith(
            isPlaying: state == PlayerState.playing,
          );
        }
      }),
    );

    _audioSubs.add(
      _audioPlayer.onDurationChanged.listen((newDuration) {
        if (mounted) {
          _audioState.value = _audioState.value.copyWith(
            totalDuration: newDuration,
          );
        }
      }),
    );

    _audioSubs.add(
      _audioPlayer.onPositionChanged.listen((newPosition) {
        if (mounted) {
          _audioState.value = _audioState.value.copyWith(
            currentPosition: newPosition,
          );
        }
      }),
    );

    _audioSubs.add(
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          _audioState.value = const AudioPlaybackState(); // reset
        }
      }),
    );
  }

  void _onScroll() {
    _removeEmojiOverlay();
    // reverse:true means oldest messages are at maxScrollExtent
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(messageProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    // Clear active chat so notifications resume for this chat
    ref.read(notificationServiceProvider).activeChatId = null;

    // Cancel audio stream subscriptions to prevent memory leaks
    for (final sub in _audioSubs) {
      sub.cancel();
    }
    _audioPlayer.dispose();
    _audioState.dispose();

    _removeEmojiOverlay();
    ref.read(messageProvider.notifier).closeChat();
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref
        .read(messageProvider.notifier)
        .sendMessage(text, replyTo: _replyMessage?['_id']);
    _messageController.clear();
    _cancelReply();
    _stopTyping();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ref.read(socketServiceProvider).startTyping(widget.chatId);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      ref.read(socketServiceProvider).stopTyping(widget.chatId);
    }
  }

  // ─── MEDIA UPLOAD HELPERS ───

  void _setUploading(bool uploading, {String type = '', double progress = 0}) {
    if (mounted) {
      setState(() {
        _isUploading = uploading;
        _uploadProgress = progress;
        _uploadingType = type;
      });
    }
  }

  void _onUploadProgress(int sent, int total) {
    if (total > 0 && mounted) {
      setState(() => _uploadProgress = sent / total);
    }
  }

  Future<void> _handleImageSend(String filePath) async {
    _setUploading(true, type: 'image');
    try {
      final media = await ref
          .read(mediaServiceProvider)
          .uploadImage(filePath, onSendProgress: _onUploadProgress);
      ref
          .read(messageProvider.notifier)
          .sendMediaMessage(type: 'image', media: media);
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to send image');
    } finally {
      _setUploading(false);
    }
  }

  Future<void> _handleVideoSend(String filePath) async {
    _setUploading(true, type: 'video');
    try {
      final media = await ref
          .read(mediaServiceProvider)
          .uploadVideo(filePath, onSendProgress: _onUploadProgress);
      ref
          .read(messageProvider.notifier)
          .sendMediaMessage(type: 'video', media: media);
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to send video');
    } finally {
      _setUploading(false);
    }
  }

  Future<void> _handleDocumentSend(String filePath, String fileName) async {
    _setUploading(true, type: 'document');
    try {
      final media = await ref
          .read(mediaServiceProvider)
          .uploadDocument(
            filePath,
            fileName,
            onSendProgress: _onUploadProgress,
          );
      ref
          .read(messageProvider.notifier)
          .sendMediaMessage(type: 'document', media: media);
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to send document');
    } finally {
      _setUploading(false);
    }
  }

  Future<void> _handleVoiceSend(
    String filePath, [
    int durationSeconds = 0,
  ]) async {
    _setUploading(true, type: 'voice');
    try {
      final media = await ref
          .read(mediaServiceProvider)
          .uploadVoice(
            filePath,
            durationSeconds: durationSeconds,
            onSendProgress: _onUploadProgress,
          );
      ref
          .read(messageProvider.notifier)
          .sendMediaMessage(type: 'voice', media: media);
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to send voice note');
    } finally {
      _setUploading(false);
    }
  }

  void _handleLocationSend(double latitude, double longitude) {
    ref
        .read(messageProvider.notifier)
        .sendMediaMessage(
          type: 'location',
          location: {'latitude': latitude, 'longitude': longitude},
        );
    _scrollToBottom();
  }

  Future<void> _handleContactSend() async {
    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) return;

      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;

      final fullContact = await FlutterContacts.getContact(
        contact.id,
        withProperties: true,
      );
      if (fullContact == null) return;

      final phone = fullContact.phones.isNotEmpty
          ? fullContact.phones.first.number
          : '';

      ref
          .read(messageProvider.notifier)
          .sendMediaMessage(
            type: 'contact',
            contactShare: {'name': fullContact.displayName, 'phone': phone},
          );
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to share contact');
    }
  }

  void _showAttachmentPicker() {
    showAttachmentPicker(
      context,
      onCamera: (xFile) => _handleImageSend(xFile.path),
      onGallery: (xFile) => _handleImageSend(xFile.path),
      onMultiGallery: (xFiles) async {
        for (final xFile in xFiles) {
          await _handleImageSend(xFile.path);
        }
      },
      onVideo: (xFile) => _handleVideoSend(xFile.path),
      onDocument: (file) {
        if (file.path != null) {
          _handleDocumentSend(file.path!, file.name);
        }
      },
      onLocation: (position) {
        _handleLocationSend(position.latitude, position.longitude);
      },
      onContact: () => _handleContactSend(),
    );
  }

  void _showGifPickerSheet() {
    showGifPicker(
      context,
      onGifSelected: (gifUrl, previewUrl) {
        ref
            .read(messageProvider.notifier)
            .sendMediaMessage(
              type: 'gif',
              media: {
                'url': gifUrl,
                'thumbnail': previewUrl,
                'mimeType': 'image/gif',
              },
            );
        _scrollToBottom();
      },
    );
  }

  void _openImageViewer(Map<String, dynamic> msg) {
    final media = msg['media'] ?? {};
    final imageUrl = media['url'] ?? media['thumbnail'] ?? '';
    if (imageUrl.toString().isEmpty) return;

    final sender = msg['senderId'];
    final senderName = sender is Map ? (sender['name'] ?? '') : '';

    Navigator.push(
      context,
      ScaleFadePageRoute(
        builder: (_) => ImageViewerScreen(
          imageUrl: imageUrl.toString(),
          senderName: senderName.toString(),
          caption: (msg['content'] ?? '').toString(),
        ),
      ),
    );
  }

  Future<void> _handleVoicePlayPause(Map<String, dynamic> msg) async {
    final msgId = msg['_id'];
    final media = msg['media'] ?? {};
    String url = media['url'] ?? '';

    if (url.isEmpty || msgId == null) return;

    final currentState = _audioState.value;
    if (currentState.playingMessageId == msgId) {
      if (currentState.isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } else {
      await _audioPlayer.stop();
      if (!url.startsWith('http')) {
        final serverRoot = ApiEndpoints.baseUrl.replaceAll('/api', '');
        url = '$serverRoot$url';
      }

      _audioState.value = AudioPlaybackState(
        playingMessageId: msgId,
        isPlaying: true,
      );
      await _audioPlayer.play(UrlSource(url));
    }
  }

  void _openVideoPlayer(Map<String, dynamic> msg) {
    final media = msg['media'] ?? {};
    final videoUrl = media['url'] ?? '';
    if (videoUrl.toString().isEmpty) return;

    final sender = msg['senderId'];
    final senderName = sender is Map ? (sender['name'] ?? '') : '';

    Navigator.push(
      context,
      ScaleFadePageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: videoUrl.toString(),
          senderName: senderName.toString(),
          caption: (msg['content'] ?? '').toString(),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgState = ref.watch(messageProvider);
    final currentUser = ref.watch(authProvider).user;
    final currentUserId = currentUser?['_id'] ?? '';

    // Watch status from chat list to update Online/Last Seen in real-time
    final chatListState = ref.watch(chatListProvider);
    final wallpaperAsync = ref.watch(chatWallpaperProvider(widget.chatId));
    final wallpaperPath =
        wallpaperAsync.value ?? 'assets/images/chatwallpaper.jpg';
    bool isOnline = widget.isOnline;
    String statusText = 'last seen recently';

    if (!widget.isGroup) {
      final currentChat = chatListState.chats.firstWhere(
        (c) => c['_id'] == widget.chatId,
        orElse: () => <String, dynamic>{},
      );

      if (currentChat.isNotEmpty) {
        final participants = currentChat['participants'];
        if (participants is List) {
          final other = participants.firstWhere(
            (p) => p is Map && p['_id'] != currentUserId,
            orElse: () => null,
          );
          if (other != null) {
            isOnline = other['isOnline'] == true;
            if (isOnline) {
              statusText = 'online';
            } else {
              final lastSeen = other['lastSeen'];
              if (lastSeen != null) {
                try {
                  final date = DateTime.parse(lastSeen.toString()).toLocal();
                  final now = DateTime.now();
                  final diff = now.difference(date);

                  String timeStr;
                  if (diff.inDays == 0) {
                    timeStr = DateFormat.jm().format(date);
                  } else if (diff.inDays == 1) {
                    timeStr = 'yesterday at ${DateFormat.jm().format(date)}';
                  } else {
                    timeStr = DateFormat('dd/MM/yy').format(date);
                  }
                  statusText = 'last seen at $timeStr';
                } catch (_) {}
              }
            }
          }
        }
      } else {
        // Fallback or just offline if chat not found yet
        if (isOnline) statusText = 'online';
      }
    } else {
      // Group: show members?
      statusText = 'tap for group info';
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final appBarBg = isDark ? AppColors.darkBgSecondary : Colors.white;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final iconColor = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF54656F);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBgPrimary
          : const Color(0xFFEFEAE2),
      appBar: _selectedMessageIds.isNotEmpty
          ? _buildSelectionAppBar(isDark, appBarBg, textColor)
          : _buildNormalAppBar(
              isDark,
              appBarBg,
              textColor,
              subtitleColor,
              iconColor,
              statusText,
              currentUserId,
              isOnline,
            ),
      body: GestureDetector(
        onTap: () {
          if (_selectedMessageIds.isNotEmpty) {
            _clearSelection();
          }
          _removeEmojiOverlay();
          FocusScope.of(context).unfocus();
        },
        child: ChatBackground(
          wallpaperPath: wallpaperPath,
          child: Column(
            children: [
              // Upload progress indicator
              if (_isUploading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: isDark ? AppColors.darkBgSecondary : AppColors.bgCard,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          size: 18,
                          color: AppColors.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sending $_uploadingType… ${(_uploadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              // Messages
              Expanded(
                child: msgState.isLoading && msgState.messages.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        reverse: true,
                        // Huge cache extent for fast 60fps scrolling
                        cacheExtent: 3000,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: msgState.messages.length,
                        itemBuilder: (context, index) {
                          final msg = msgState.messages[index];
                          final isMe =
                              (msg['senderId']?['_id'] ?? msg['senderId']) ==
                              currentUserId;
                          final showDate = _shouldShowDate(
                            msgState.messages,
                            index,
                          );

                          return RepaintBoundary(
                            child: Column(
                              children: [
                                if (showDate)
                                  _DateSeparator(date: msg['createdAt'] ?? ''),
                                _buildMessageBubble(msg, isMe),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Input bar or blocked message
              if (_isBlockedByMe || _isBlockedByThem)
                _buildBlockedBar(isDark)
              else
                _InputBar(
                  controller: _messageController,
                  onSend: _sendMessage,
                  onChanged: _onTextChanged,
                  onAttachment: _showAttachmentPicker,
                  onVoiceSend: _handleVoiceSend,
                  onGif: _showGifPickerSheet,
                  isUploading: _isUploading,
                  replyMessage: _replyMessage,
                  onCancelReply: _cancelReply,
                  onCamera: () async {
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (photo != null) {
                      _handleImageSend(photo.path);
                    }
                  },
                  onGifSelected: (url, thumb) {
                    ref
                        .read(messageProvider.notifier)
                        .sendMediaMessage(
                          type: 'gif',
                          media: {
                            'url': url,
                            'thumbnail': thumb,
                            'mimeType': 'image/gif',
                          },
                        );
                    _scrollToBottom();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    bool isDark,
    Color appBarBg,
    Color textColor,
  ) {
    final msgState = ref.watch(messageProvider);
    final selectedCount = _selectedMessageIds.length;
    final currentUserId = ref.read(authProvider).user?['_id'] ?? '';

    // Gather selected messages once for all button checks
    final selectedMessages = <Map<String, dynamic>>[];
    for (final id in _selectedMessageIds) {
      final msg = msgState.messages.firstWhere(
        (m) => m['_id'] == id,
        orElse: () => <String, dynamic>{},
      );
      if (msg.isNotEmpty) selectedMessages.add(msg);
    }

    bool canCopy = selectedMessages.any((m) => (m['type'] ?? 'text') == 'text');

    return AppBar(
      backgroundColor: appBarBg,
      elevation: 1,
      leading: IconButton(
        icon: Icon(Icons.close, color: textColor),
        onPressed: () {
          _removeEmojiOverlay();
          _clearSelection();
        },
      ),
      title: Text(
        selectedCount.toString(),
        style: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Reply (single message only)
        if (selectedCount == 1)
          IconButton(
            icon: Icon(Icons.reply, color: textColor),
            onPressed: () {
              _removeEmojiOverlay();
              final msg = selectedMessages.isNotEmpty
                  ? selectedMessages.first
                  : null;
              _clearSelection();
              if (msg != null) _onReply(msg);
            },
          ),
        // Star / Unstar
        IconButton(
          icon: Icon(Icons.star_border, color: textColor),
          onPressed: () async {
            _removeEmojiOverlay();
            final ids = [..._selectedMessageIds];
            _clearSelection();
            for (final id in ids) {
              try {
                await ref
                    .read(chatServiceProvider)
                    .starMessage(widget.chatId, id);
              } catch (_) {}
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ids.length == 1
                        ? 'Message starred'
                        : '${ids.length} messages starred',
                  ),
                ),
              );
            }
          },
        ),
        // Delete (handles ALL selected messages)
        IconButton(
          icon: Icon(Icons.delete, color: textColor),
          onPressed: () {
            _removeEmojiOverlay();
            final msgs = [...selectedMessages];
            _clearSelection();
            if (msgs.isNotEmpty) {
              _showBulkDeleteOptions(msgs);
            }
          },
        ),
        // Copy (text messages only)
        if (canCopy)
          IconButton(
            icon: Icon(Icons.copy, color: textColor),
            onPressed: () {
              _removeEmojiOverlay();
              String copiedText = '';
              for (final msg in selectedMessages) {
                if ((msg['type'] ?? 'text') == 'text') {
                  copiedText += (msg['content'] ?? '') + '\n';
                }
              }
              Clipboard.setData(ClipboardData(text: copiedText.trim()));
              _clearSelection();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Message copied')));
            },
          ),
        // Forward
        IconButton(
          icon: Icon(Icons.forward, color: textColor),
          onPressed: () {
            _removeEmojiOverlay();
            final msgs = List<Map<String, dynamic>>.from(selectedMessages);
            _clearSelection();
            if (msgs.isNotEmpty) _showForwardDialog(msgs);
          },
        ),
      ],
    );
  }

  PreferredSizeWidget _buildNormalAppBar(
    bool isDark,
    Color appBarBg,
    Color textColor,
    Color subtitleColor,
    Color iconColor,
    String statusText,
    String currentUserId,
    bool isOnline,
  ) {
    return AppBar(
      titleSpacing: 0,
      backgroundColor: appBarBg,
      elevation: 1,
      iconTheme: IconThemeData(color: iconColor),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: InkWell(
        onTap: () {
          if (widget.isGroup) {
            Navigator.push(
              context,
              InfexorPageRoute(
                page: GroupInfoScreen(groupId: _groupId, chatId: widget.chatId),
              ),
            );
          } else {
            // Construct a user map from available info
            Map<String, dynamic> userMap = {
              'name': widget.chatName,
              'avatar': UrlUtils.getFullUrl(widget.chatAvatar),
              'isOnline': widget.isOnline,
            };

            // Try to find full user details from chat participant list
            final chatListState = ref.read(chatListProvider);
            final currentChat = chatListState.chats.firstWhere(
              (c) => c['_id'] == widget.chatId,
              orElse: () => <String, dynamic>{},
            );

            if (currentChat.isNotEmpty) {
              final participants = currentChat['participants'];
              if (participants is List) {
                final other = participants.firstWhere(
                  (p) => p is Map && p['_id'] != currentUserId,
                  orElse: () => null,
                );
                if (other != null) {
                  userMap = Map<String, dynamic>.from(other);
                }
              }
            }

            Navigator.push(
              context,
              InfexorPageRoute(
                page: UserProfileScreen(
                  user: userMap,
                  chatId: widget.chatId,
                  contactName: widget.chatName,
                ),
              ),
            );
          }
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.border,
              backgroundImage: widget.chatAvatar.isNotEmpty
                  ? CachedNetworkImageProvider(
                      UrlUtils.getFullUrl(widget.chatAvatar),
                    )
                  : null,
              child: widget.chatAvatar.isEmpty
                  ? Text(
                      widget.chatName.isNotEmpty
                          ? widget.chatName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOnline ? AppColors.online : subtitleColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_rounded),
          onPressed: () {
            final chatListState = ref.read(chatListProvider);
            final currentChat = chatListState.chats.firstWhere(
              (c) => c['_id'] == widget.chatId,
              orElse: () => <String, dynamic>{},
            );
            String targetUserId = '';
            if (currentChat.isNotEmpty) {
              final participants = currentChat['participants'];
              if (participants is List) {
                final currentUser = ref.read(authProvider).user;
                final currentUserId = currentUser?['_id'] ?? '';
                final other = participants.firstWhere(
                  (p) => p is Map && p['_id'] != currentUserId,
                  orElse: () => null,
                );
                if (other != null) targetUserId = other['_id'];
              }
            }

            if (targetUserId.isNotEmpty) {
              Navigator.push(
                context,
                ScaleFadePageRoute(
                  builder: (_) => CallPage(
                    chatId: widget.chatId,
                    userId: targetUserId,
                    callerName: widget.chatName,
                    callerAvatar: widget.chatAvatar,
                    isVideoCall: true,
                    isIncoming: false,
                  ),
                ),
              );
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.call_rounded),
          onPressed: () {
            final chatListState = ref.read(chatListProvider);
            final currentChat = chatListState.chats.firstWhere(
              (c) => c['_id'] == widget.chatId,
              orElse: () => <String, dynamic>{},
            );
            String targetUserId = '';
            if (currentChat.isNotEmpty) {
              final participants = currentChat['participants'];
              if (participants is List) {
                final currentUser = ref.read(authProvider).user;
                final currentUserId = currentUser?['_id'] ?? '';
                final other = participants.firstWhere(
                  (p) => p is Map && p['_id'] != currentUserId,
                  orElse: () => null,
                );
                if (other != null) targetUserId = other['_id'];
              }
            }

            if (targetUserId.isNotEmpty) {
              Navigator.push(
                context,
                ScaleFadePageRoute(
                  builder: (_) => CallPage(
                    chatId: widget.chatId,
                    userId: targetUserId,
                    callerName: widget.chatName,
                    callerAvatar: widget.chatAvatar,
                    isVideoCall: false,
                    isIncoming: false,
                  ),
                ),
              );
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showChatOptions,
        ),
      ],
    );
  }

  void _showChatOptions() {
    final sheetBg = Theme.of(context).scaffoldBackgroundColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('View Contact'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.wallpaper),
                title: const Text('Wallpaper'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    AnimatedPageRoute(
                      builder: (_) =>
                          WallpaperSelectionScreen(chatId: widget.chatId),
                      slideDirection: SlideDirection.up,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.danger),
                title: const Text(
                  'Block',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    // If deleted for everyone, always show tombstone regardless of type field
    if (msg['deletedForEveryone'] == true) {
      return _RevokedMessageBubble(message: msg, isMe: isMe);
    }

    final type = msg['type'] ?? 'text';
    Widget bubble;

    switch (type) {
      case 'image':
        bubble = ImageBubble(
          message: msg,
          isMe: isMe,
          onTap: () => _openImageViewer(msg),
        );
        break;
      case 'video':
        bubble = VideoBubble(
          message: msg,
          isMe: isMe,
          onTap: () => _openVideoPlayer(msg),
        );
        break;
      case 'voice':
      case 'audio':
        // Use ValueListenableBuilder so only this bubble rebuilds on playback ticks
        bubble = ValueListenableBuilder<AudioPlaybackState>(
          valueListenable: _audioState,
          builder: (context, audioState, _) {
            final isPlayingThis =
                audioState.playingMessageId == msg['_id'] &&
                audioState.isPlaying;
            double progress = 0.0;
            if (audioState.playingMessageId == msg['_id'] &&
                audioState.totalDuration.inMilliseconds > 0) {
              progress =
                  audioState.currentPosition.inMilliseconds /
                  audioState.totalDuration.inMilliseconds;
            }
            return VoiceBubble(
              message: msg,
              isMe: isMe,
              isPlaying: isPlayingThis,
              progress: progress,
              onPlayPause: () => _handleVoicePlayPause(msg),
            );
          },
        );
        break;
      case 'document':
        bubble = DocumentBubble(message: msg, isMe: isMe);
        break;
      case 'location':
        bubble = LocationBubble(message: msg, isMe: isMe);
        break;
      case 'contact':
        bubble = ContactBubble(message: msg, isMe: isMe);
        break;
      case 'gif':
        bubble = ImageBubble(
          message: msg,
          isMe: isMe,
          onTap: () => _openImageViewer(msg),
        );
        break;
      case 'system':
        return _SystemMessageBubble(message: msg);
      case 'revoked':
        return _RevokedMessageBubble(message: msg, isMe: isMe);
      default:
        bubble = _TextMessageBubble(message: msg, isMe: isMe);
    }

    if (type == 'revoked') {
      return bubble;
    }

    final msgId = msg['_id']?.toString() ?? '';
    final isNew = msgId.isNotEmpty && _seenMessageIds.add(msgId);
    final isSelected = _selectedMessageIds.contains(msgId);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget child = GestureDetector(
      onTapDown: (details) {
        _tapPosition = details.globalPosition;
      },
      onLongPress: () {
        if (msgId.isNotEmpty && _selectedMessageIds.isEmpty) {
          _toggleSelection(msgId);
          HapticFeedback.lightImpact();
        }
      },
      onTap: () {
        if (_selectedMessageIds.isNotEmpty && msgId.isNotEmpty) {
          _toggleSelection(msgId);
          _removeEmojiOverlay();
        } else {
          // Default tap action. For text, none by default.
          // Media bubbles handle their own taps.
        }
      },
      child: Container(
        color: isSelected
            ? AppColors.accentBlue.withValues(alpha: 0.3)
            : Colors.transparent,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: bubble,
      ),
    );

    return child;
  }

  void _removeEmojiOverlay() {
    _emojiOverlayEntry?.remove();
    _emojiOverlayEntry = null;
  }

  void _showEmojiReactionOverlay(BuildContext context, String messageId) {
    if (_tapPosition == null) return;

    _removeEmojiOverlay();

    final size = MediaQuery.of(context).size;
    // Calculate position: just above the tap if possible
    double top = _tapPosition!.dy - 60;
    if (top < 100) top = _tapPosition!.dy + 40; // show below if too high

    // The emoji bar is roughly ~280px wide. We offset it and clamp it to avoid screen edges.
    double left = _tapPosition!.dx - 140;
    left = math.max(16.0, left);
    left = math.min(left, size.width - 300.0);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF233138) : Colors.white;

    _emojiOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss area
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _removeEmojiOverlay();
                // Don't clear selection — let user use the action bar
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          // Emoji Bar
          Positioned(
            top: top,
            left: left,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildEmojiReaction('👍', messageId, 0),
                          _buildEmojiReaction('❤️', messageId, 1),
                          _buildEmojiReaction('😂', messageId, 2),
                          _buildEmojiReaction('😮', messageId, 3),
                          _buildEmojiReaction('😢', messageId, 4),
                          _buildEmojiReaction('🙏', messageId, 5),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_emojiOverlayEntry!);
  }

  Widget _buildEmojiReaction(String emoji, String messageId, int index) {
    return _BouncingEmoji(
      emoji: emoji,
      index: index,
      onTap: () {
        _removeEmojiOverlay();
        // Keep selection active — user can still use action bar after reacting
        ref.read(messageProvider.notifier).reactToMessage(messageId, emoji);
      },
    );
  }

  void _showDeleteOptions(Map<String, dynamic> msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'You can delete messages for everyone or just for yourself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMessage(msg['_id'], forEveryone: true);
            },
            child: const Text(
              'Delete for everyone',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMessage(msg['_id'], forEveryone: false);
            },
            child: const Text(
              'Delete for me',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteOptions(List<Map<String, dynamic>> msgs) {
    final count = msgs.length;
    final currentUserId = ref.read(authProvider).user?['_id'] ?? '';

    // Only show "Delete for everyone" if ALL selected messages are mine
    final allMine = msgs.every((msg) {
      final senderId = msg['senderId']?['_id'] ?? msg['senderId'];
      return senderId == currentUserId;
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count message${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (allMine)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                for (final msg in msgs) {
                  _deleteMessage(msg['_id'], forEveryone: true);
                }
              },
              child: const Text(
                'Delete for everyone',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final msg in msgs) {
                _deleteMessage(msg['_id'], forEveryone: false);
              }
            },
            child: const Text(
              'Delete for me',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(
    String? messageId, {
    required bool forEveryone,
  }) async {
    if (messageId == null) return;
    try {
      await ref
          .read(messageProvider.notifier)
          .deleteMessage(messageId, forEveryone);
      if (forEveryone && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You wiped this data'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to delete message');
    }
  }

  Future<void> _forwardMessages(
    List<String> messageIds,
    List<String> targetChatIds,
  ) async {
    try {
      final service = ref.read(chatServiceProvider);
      for (final messageId in messageIds) {
        for (final targetId in targetChatIds) {
          await service.forwardMessage(widget.chatId, messageId, targetId);
        }
      }
      if (mounted) {
        final msgCount = messageIds.length;
        final chatCount = targetChatIds.length;
        String text;
        if (msgCount == 1 && chatCount == 1) {
          text = 'Message forwarded';
        } else if (msgCount == 1) {
          text = 'Message forwarded to $chatCount chats';
        } else if (chatCount == 1) {
          text = '$msgCount messages forwarded';
        } else {
          text = '$msgCount messages forwarded to $chatCount chats';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to forward messages');
      }
    }
  }

  void _showForwardDialog(List<Map<String, dynamic>> msgs) {
    final chatListState = ref.read(chatListProvider);
    if (chatListState.chats.isEmpty && !chatListState.isLoading) {
      ref.read(chatListProvider.notifier).loadChats();
    }

    Box? contactsBox;
    try {
      if (Hive.isBoxOpen('contacts_cache')) {
        contactsBox = Hive.box('contacts_cache');
      }
    } catch (_) {}

    final messageIds = msgs
        .map((m) => m['_id']?.toString())
        .where((id) => id != null)
        .cast<String>()
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _ForwardChatPicker(
          currentChatId: widget.chatId,
          contactsBox: contactsBox,
          onForward: (selectedIds) {
            Navigator.pop(ctx);
            _forwardMessages(messageIds, selectedIds);
          },
        );
      },
    );
  }

  bool _shouldShowDate(List<Map<String, dynamic>> messages, int index) {
    if (index == messages.length - 1) return true;
    try {
      final current = DateTime.parse(messages[index]['createdAt'] ?? '');
      final older = DateTime.parse(messages[index + 1]['createdAt'] ?? '');
      return current.day != older.day ||
          current.month != older.month ||
          current.year != older.year;
    } catch (_) {
      return false;
    }
  }

  /// Check block status for 1:1 chats
  Future<void> _checkBlockStatus() async {
    try {
      final currentUserId = ref.read(authProvider).user?['_id'] ?? '';
      final chatListState = ref.read(chatListProvider);
      final currentChat = chatListState.chats.firstWhere(
        (c) => c['_id'] == widget.chatId,
        orElse: () => <String, dynamic>{},
      );

      if (currentChat.isNotEmpty) {
        final participants = currentChat['participants'];
        if (participants is List) {
          final other = participants.firstWhere(
            (p) => p is Map && p['_id'] != currentUserId,
            orElse: () => null,
          );
          if (other != null && other is Map) {
            _otherUserId = other['_id']?.toString();
          }
        }
      }

      if (_otherUserId != null) {
        final result = await ref
            .read(userServiceProvider)
            .checkBlockStatus(_otherUserId!);
        if (mounted) {
          setState(() {
            _isBlockedByMe = result['blockedByMe'] == true;
            _isBlockedByThem = result['blockedByThem'] == true;
          });
        }
      }
    } catch (e) {
      debugPrint('Block check failed: $e');
    }
  }

  /// Build blocked message bar (replaces input bar when blocked)
  Widget _buildBlockedBar(bool isDark) {
    final bgColor = isDark ? AppColors.darkBgSecondary : Colors.white;
    final textColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    if (_isBlockedByMe) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        color: bgColor,
        child: GestureDetector(
          onTap: () async {
            // Unblock action
            if (_otherUserId == null) return;
            try {
              await ref.read(userServiceProvider).unblockUser(_otherUserId!);
              if (mounted) {
                setState(() {
                  _isBlockedByMe = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact unblocked')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to unblock')),
                );
              }
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, color: AppColors.danger, size: 18),
              const SizedBox(width: 8),
              Text(
                'You blocked this contact. Tap to unblock.',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Blocked by them
      return Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        color: bgColor,
        child: Center(
          child: Text(
            'You can\'t send messages to this contact.',
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ),
      );
    }
  }
}

class _DateSeparator extends StatelessWidget {
  final String date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String label;
    try {
      final d = DateTime.parse(date).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inDays == 0) {
        label = 'Today';
      } else if (diff.inDays == 1) {
        label = 'Yesterday';
      } else {
        label = DateFormat('MMMM d, yyyy').format(d);
      }
    } catch (_) {
      label = '';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgSecondary : AppColors.bgCard,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const _SystemMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = message['content'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBgSecondary.withValues(alpha: 0.7)
                : AppColors.bgCard.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const _TextMessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final content = message['content'] ?? '';
    final status = message['status'] ?? 'sent';
    final createdAt = message['createdAt'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bubbleBgMe = isDark
        ? AppColors.darkMsgSentBgBlue
        : AppColors.msgSentBg;
    final bubbleBgOther = isDark
        ? AppColors.darkMsgReceivedBg
        : AppColors.msgReceivedBg;
    final msgTextColor = isDark
        ? AppColors.darkTextPrimary
        : const Color(0xFF111B21);
    final timeColor = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF667781);

    String time = '';
    try {
      time = DateFormat.jm().format(DateTime.parse(createdAt).toLocal());
    } catch (_) {}

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
        decoration: BoxDecoration(
          color: isMe ? bubbleBgMe : bubbleBgOther,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message['replyTo'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ReplyPreview(replyTo: message['replyTo'], isMe: isMe),
                ),
              // Content
              Text(
                content,
                style: TextStyle(
                  color: isMe && isDark ? Colors.white : msgTextColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              // Time & Status
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe && isDark ? Colors.white70 : timeColor,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(status, timeColor),
                  ],
                ],
              ),
              // Reactions
              if (message['reactions'] != null &&
                  (message['reactions'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2B33) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.transparent
                              : Colors.grey.shade300,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        (message['reactions'] as List)
                            .map((r) => r['emoji'] ?? '')
                            .join(' '),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status, Color tickColor) {
    Widget icon;
    switch (status) {
      case 'read':
        icon = Icon(
          Icons.done_all,
          key: const ValueKey('read'),
          size: 16,
          color: AppColors.checkRead,
        );
        break;
      case 'delivered':
        icon = Icon(
          Icons.done_all,
          key: const ValueKey('delivered'),
          size: 16,
          color: tickColor,
        );
        break;
      case 'sent':
        icon = Icon(
          Icons.done,
          key: const ValueKey('sent'),
          size: 16,
          color: tickColor,
        );
        break;
      default:
        icon = Icon(
          Icons.access_time,
          key: const ValueKey('time'),
          size: 14,
          color: tickColor,
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: icon,
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final VoidCallback onAttachment;
  final Future<void> Function(String path, [int durationSeconds]) onVoiceSend;
  final VoidCallback onGif;
  final bool isUploading;
  final Map<String, dynamic>? replyMessage;
  final VoidCallback? onCancelReply;
  final VoidCallback? onCamera;
  final void Function(String, String)? onGifSelected;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onChanged,
    required this.onAttachment,
    required this.onVoiceSend,
    required this.onGif,
    this.isUploading = false,
    this.replyMessage,
    this.onCancelReply,
    this.onCamera,
    this.onGifSelected,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> with TickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  double _dragOffset = 0.0;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordPath;
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  late AnimationController _voiceAnimController;
  late Animation<double> _voiceScaleAnim;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showEmojiPicker = false);
      }
    });

    _voiceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _voiceScaleAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _voiceAnimController, curve: Curves.easeInOut),
    );

    _voiceAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _voiceAnimController.reverse();
      } else if (status == AnimationStatus.dismissed && _isRecording) {
        _voiceAnimController.forward();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _focusNode.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    _voiceAnimController.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmojiPicker = !_showEmojiPicker);
  }

  Future<void> _startRecording() async {
    // Check permission
    if (!await _recorder.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    _recordPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordPath!,
    );

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });

    _voiceAnimController.forward();

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordTimer?.cancel();
    _voiceAnimController.stop();
    _voiceAnimController.reset();

    final path = await _recorder.stop();
    setState(() => _isRecording = false);

    if (!cancel && path != null && _recordSeconds > 0) {
      widget.onVoiceSend(path, _recordSeconds);
    }
  }

  String get _timeDisplay {
    final mins = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBg = isDark ? AppColors.darkInputBg : Colors.white;
    final iconColor = isDark ? Colors.grey[400] : const Color(0xFF54656F);
    final textColor = isDark ? Colors.white : const Color(0xFF111B21);
    final hintColor = isDark ? Colors.grey[500] : const Color(0xFF667781);
    final micColor = AppColors.primaryPurple; // Theme request: Purple
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return GlassMorphism(
      color: isDark ? AppColors.darkBgSecondary : Colors.white,
      opacity: 0.85,
      blur: 12.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Container(width: 4, height: 40, color: AppColors.accentBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Replying to',
                          style: TextStyle(
                            color: AppColors.accentBlue,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          widget.replyMessage!['content']?.toString() ??
                              'Media',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: iconColor),
                    onPressed: widget.onCancelReply,
                  ),
                ],
              ),
            ),

          Container(
            padding: EdgeInsets.fromLTRB(
              8,
              8,
              8,
              8 + MediaQuery.of(context).padding.bottom, // Safe area padding
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isRecording) ...[
                  // Recording UI - Styled
                  Expanded(
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mic, color: Colors.red, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            _timeDisplay,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Slide to cancel <',
                            style: TextStyle(
                              color: Colors.grey.withOpacity(
                                (1.0 + (_dragOffset / 100)).clamp(0.0, 1.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Custom Attachment Button
                  Container(
                    margin: const EdgeInsets.only(bottom: 2, right: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add, color: AppColors.primaryPurple),
                      onPressed: widget.isUploading
                          ? null
                          : widget.onAttachment,
                    ),
                  ),

                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(
                              _showEmojiPicker
                                  ? Icons.keyboard
                                  : Icons.emoji_emotions_outlined,
                              color:
                                  AppColors.primaryPurple, // Custom Emoji Color
                              size: 24,
                            ),
                            onPressed: _toggleEmojiPicker,
                          ),
                          Expanded(
                            child: TextField(
                              focusNode: _focusNode,
                              controller: widget.controller,
                              onChanged: (value) {
                                setState(() {});
                                widget.onChanged(value);
                              },
                              style: TextStyle(color: textColor, fontSize: 16),
                              maxLines: 6,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(color: hintColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 0,
                                ),
                                isDense: true,
                              ),
                              textInputAction: TextInputAction.newline,
                            ),
                          ),
                          if (widget.controller.text.isEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.camera_alt_rounded,
                                color: AppColors.primaryPurple,
                              ),
                              onPressed: widget.isUploading
                                  ? null
                                  : widget.onCamera,
                            ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 8),

                // Custom Send / Mic Button
                GestureDetector(
                  onLongPressStart: (_) {
                    if (widget.controller.text.trim().isEmpty &&
                        !widget.isUploading) {
                      setState(() => _dragOffset = 0.0);
                      _startRecording();
                    }
                  },
                  onLongPressMoveUpdate: (details) {
                    if (_isRecording && details.localPosition.dx < 0) {
                      setState(() {
                        _dragOffset = details.localPosition.dx;
                      });
                    }
                  },
                  onLongPressEnd: (details) {
                    if (_isRecording) {
                      if (_dragOffset < -60) {
                        _stopRecording(cancel: true);
                      } else {
                        _stopRecording(cancel: false);
                      }
                      setState(() => _dragOffset = 0.0);
                    }
                  },
                  onTap: () {
                    if (widget.controller.text.trim().isNotEmpty) {
                      widget.onSend();
                    } else {
                      // Mic tap animation feedback
                      HapticFeedback.lightImpact();
                      _voiceAnimController.forward().then((_) {
                        _voiceAnimController.reverse();
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    child: Transform.translate(
                      offset: Offset(_dragOffset, 0),
                      child: ScaleTransition(
                        scale: _voiceScaleAnim,
                        child: Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [micColor, micColor.withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _isRecording
                                    ? Colors.red.withOpacity(0.5)
                                    : micColor.withOpacity(0.4),
                                blurRadius: _isRecording ? 12 : 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.controller.text.trim().isNotEmpty
                                ? Icons.send_rounded
                                : _dragOffset < -40
                                ? Icons.delete_outline
                                : _isRecording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showEmojiPicker)
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  // Blur Effect
                  Positioned.fill(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color:
                              (isDark
                                      ? AppColors.darkBgSecondary
                                      : const Color(0xFFF2F2F2))
                                  .withOpacity(0.85),
                        ),
                      ),
                    ),
                  ),
                  // Picker Content
                  Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        indicatorColor: micColor,
                        labelColor: isDark ? Colors.white : Colors.black,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(icon: Icon(Icons.emoji_emotions_outlined)),
                          Tab(icon: Icon(Icons.gif)),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            EmojiPicker(
                              textEditingController: widget.controller,
                              onEmojiSelected: (category, emoji) {
                                setState(() {});
                              },
                              config: Config(
                                checkPlatformCompatibility: true,
                                emojiViewConfig: EmojiViewConfig(
                                  backgroundColor: Colors.transparent,
                                  columns: 7,
                                  emojiSizeMax: 28,
                                ),
                                skinToneConfig: SkinToneConfig(
                                  dialogBackgroundColor: isDark
                                      ? AppColors.darkBgSecondary
                                      : Colors.white,
                                  indicatorColor: AppColors.primaryPurple,
                                ),
                                categoryViewConfig: CategoryViewConfig(
                                  indicatorColor: AppColors.primaryPurple,
                                  iconColorSelected: AppColors.primaryPurple,
                                  backspaceColor: AppColors.primaryPurple,
                                  tabBarHeight: 46,
                                  backgroundColor: Colors
                                      .transparent, // Ensure bar is transparent
                                ),
                                bottomActionBarConfig:
                                    const BottomActionBarConfig(enabled: false),
                                searchViewConfig: SearchViewConfig(
                                  backgroundColor: isDark
                                      ? AppColors.darkBgSecondary
                                      : AppColors.bgSecondary,
                                ),
                              ),
                            ),
                            GifPicker(
                              isInline: true,
                              onGifSelected: (gifUrl, previewUrl) {
                                widget.onGifSelected?.call(gifUrl, previewUrl);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BouncingEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;
  final int index;

  const _BouncingEmoji({
    required this.emoji,
    required this.onTap,
    required this.index,
  });

  @override
  State<_BouncingEmoji> createState() => _BouncingEmojiState();
}

class _BouncingEmojiState extends State<_BouncingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.reverse(from: 0.5).then((_) => widget.onTap());
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}

class _ForwardChatPicker extends ConsumerStatefulWidget {
  final String currentChatId;
  final Box? contactsBox;
  final void Function(List<String> selectedChatIds) onForward;

  const _ForwardChatPicker({
    required this.currentChatId,
    required this.onForward,
    this.contactsBox,
  });

  @override
  ConsumerState<_ForwardChatPicker> createState() => _ForwardChatPickerState();
}

class _ForwardChatPickerState extends ConsumerState<_ForwardChatPicker> {
  final Set<String> _selected = {};
  final _searchController = TextEditingController();
  String _query = '';
  static const int _maxForward = 6;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getChatName(Map<String, dynamic> chat) {
    final isGroup = chat['type'] == 'group';
    final groupData = chat['groupId'];
    if (isGroup && groupData is Map) {
      return groupData['name']?.toString() ?? 'Group';
    }

    final currentUserId = ref.read(authProvider).user?['_id'] ?? '';
    try {
      final rawParticipants = chat['participants'] ?? [];
      final participants = <Map<String, dynamic>>[];
      if (rawParticipants is List) {
        for (final p in rawParticipants) {
          if (p is Map) participants.add(Map<String, dynamic>.from(p));
        }
      }
      final other = participants.firstWhere(
        (p) => p['_id'] != currentUserId,
        orElse: () => <String, dynamic>{'name': 'Unknown'},
      );
      final otherId = other['_id']?.toString();
      String? savedName;
      if (otherId != null &&
          widget.contactsBox != null &&
          widget.contactsBox!.isOpen) {
        savedName = widget.contactsBox!.get(otherId)?.toString();
      }
      final phone = other['phone']?.toString();
      final registeredName = other['name']?.toString();
      final formattedPhone = PhoneUtils.formatPhoneDisplay(phone);
      return savedName ??
          (formattedPhone.isNotEmpty
              ? formattedPhone
              : registeredName ?? 'Unknown');
    } catch (_) {
      return 'Unknown';
    }
  }

  String _getChatAvatar(Map<String, dynamic> chat) {
    final isGroup = chat['type'] == 'group';
    final groupData = chat['groupId'];
    if (isGroup && groupData is Map) {
      return groupData['avatar']?.toString() ?? '';
    }

    final currentUserId = ref.read(authProvider).user?['_id'] ?? '';
    try {
      final rawParticipants = chat['participants'] ?? [];
      for (final p in rawParticipants) {
        if (p is Map && p['_id'] != currentUserId) {
          return p['avatar']?.toString() ?? '';
        }
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final inputBg = isDark ? AppColors.darkInputBg : const Color(0xFFF0F2F5);

    final allChats = state.chats
        .where((c) => c['_id'] != widget.currentChatId)
        .toList();

    final chats = _query.isEmpty
        ? allChats
        : allChats.where((c) {
            final name = _getChatName(c).toLowerCase();
            return name.contains(_query.toLowerCase());
          }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: subtitleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Forward to...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    Text(
                      '${_selected.length}/$_maxForward',
                      style: TextStyle(fontSize: 14, color: subtitleColor),
                    ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: TextStyle(color: subtitleColor),
                  prefixIcon: Icon(Icons.search, color: subtitleColor),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

            // Selected chips
            if (_selected.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selected.map((chatId) {
                    final chat = allChats.firstWhere(
                      (c) => c['_id'] == chatId,
                      orElse: () => <String, dynamic>{},
                    );
                    final name = chat.isNotEmpty
                        ? _getChatName(chat)
                        : 'Unknown';
                    return Chip(
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _selected.remove(chatId)),
                      backgroundColor: const Color(0xFFE7F8E9),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),

            const Divider(height: 1),

            // Chat list
            Expanded(
              child: state.isLoading && allChats.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : chats.isEmpty
                  ? Center(
                      child: Text(
                        'No chats found',
                        style: TextStyle(color: subtitleColor),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final chatId = chat['_id']?.toString() ?? '';
                        final name = _getChatName(chat);
                        final avatar = _getChatAvatar(chat);
                        final isGroup = chat['type'] == 'group';
                        final isSelected = _selected.contains(chatId);

                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: inputBg,
                                backgroundImage: avatar.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        UrlUtils.getFullUrl(avatar),
                                      )
                                    : null,
                                child: avatar.isEmpty
                                    ? Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: subtitleColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : null,
                              ),
                              if (isSelected)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accentBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                          subtitle: isGroup
                              ? Text(
                                  'Group',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.accentBlue,
                                )
                              : Icon(
                                  Icons.radio_button_unchecked,
                                  color: subtitleColor,
                                ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selected.remove(chatId);
                              } else if (_selected.length < _maxForward) {
                                _selected.add(chatId);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'You can forward to a maximum of 6 chats',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          },
                        );
                      },
                    ),
            ),

            // Send button
            if (_selected.isNotEmpty)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onForward(_selected.toList()),
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: Text(
                        _selected.length == 1
                            ? 'Send'
                            : 'Send to ${_selected.length} chats',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RevokedMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const _RevokedMessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBgMe = isDark
        ? AppColors.darkMsgSentBgBlue
        : AppColors.msgSentBg;
    final bubbleBgOther = isDark
        ? AppColors.darkMsgReceivedBg
        : AppColors.msgReceivedBg;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textMuted;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? bubbleBgMe : bubbleBgOther,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 16, color: mutedColor),
            const SizedBox(width: 8),
            Text(
              isMe ? 'You deleted this message' : 'This message was deleted',
              style: TextStyle(
                color: mutedColor,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
