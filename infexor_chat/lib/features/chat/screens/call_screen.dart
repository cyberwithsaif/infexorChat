import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import '../../../core/services/webrtc_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/providers/active_call_provider.dart';
import '../services/socket_service.dart';
import '../providers/call_history_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auth/providers/auth_provider.dart';

class CallPage extends ConsumerStatefulWidget {
  final String chatId;
  final String userId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideoCall;
  final bool isIncoming;
  final bool isResuming;
  final int initialDuration;

  const CallPage({
    super.key,
    required this.chatId,
    required this.userId,
    this.callerName = 'Unknown',
    this.callerAvatar,
    this.isVideoCall = true,
    this.isIncoming = false,
    this.isResuming = false,
    this.initialDuration = 0,
  });

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage>
    with TickerProviderStateMixin {
  final _webRTCService = WebRTCService();
  bool _micEnabled = true;
  bool _speakerEnabled = false;
  bool _videoEnabled = true;
  bool _isConnected = false;
  bool _disposed = false;
  bool _minimized = false;
  String _callStatus = 'Connecting...';
  Timer? _callTimer;
  int _callDuration = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Controls visibility for video call
  bool _showControls = true;
  Timer? _controlsTimer;
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsFadeAnimation;
  late Animation<Offset> _controlsSlideAnimation;

  @override
  void initState() {
    super.initState();
    _callDuration = widget.initialDuration;
    _videoEnabled = widget.isVideoCall;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Controls show/hide animation
    _controlsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _controlsFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controlsAnimController, curve: Curves.easeOut),
    );
    _controlsSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controlsAnimController,
            curve: Curves.easeOut,
          ),
        );
    // Start with controls visible
    _controlsAnimController.value = 1.0;

    if (widget.isResuming) {
      _isConnected = true;
      _callStatus = 'Connected';
      _setupSocketListeners();
      _startTimer();
      if (widget.isVideoCall) {
        Helper.setSpeakerphoneOn(true);
        _speakerEnabled = true;
        _startControlsAutoHide();
      } else {
        Helper.setSpeakerphoneOn(false);
        _speakerEnabled = false;
      }
    } else {
      _initCall();
    }
  }

  void _setupSocketListeners() {
    final socketService = ref.read(socketServiceProvider);

    // Listen for ALL possible call-end events from server
    for (final event in ['call:ended', 'call:end', 'call:hangup']) {
      socketService.on(event, (data) {
        if (_disposed) return;
        debugPrint('📞 Received $event from server');
        if (data is Map<String, dynamic>) {
          final eventChatId = data['chatId']?.toString();
          if (eventChatId != null && eventChatId != widget.chatId) return;
        }
        _endCallFromRemote();
      });
    }

    // Listen for call accepted (outgoing call - callee accepted)
    socketService.on('call:accepted', (data) {
      if (_disposed) return;
      debugPrint('📞 Call accepted by remote');
      if (mounted) {
        setState(() => _callStatus = 'Connecting...');
      }
    });

    // Listen for call rejected
    socketService.on('call:rejected', (data) {
      if (_disposed) return;
      debugPrint('📞 Call rejected by remote');
      _endCallLocally();
    });
  }

  Future<void> _initCall() async {
    await [Permission.microphone, Permission.camera].request();

    final socketService = ref.read(socketServiceProvider);
    final socket = socketService.socket;
    if (socket == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    await _webRTCService.init(socket);

    // Immediately set audio routing BEFORE media starts flowing
    // Audio calls → earpiece; Video calls → loudspeaker
    if (!widget.isVideoCall) {
      Helper.setSpeakerphoneOn(false);
    } else {
      Helper.setSpeakerphoneOn(true);
    }

    // Set up callbacks for remote stream and connection
    _webRTCService.onRemoteStream = () {
      if (mounted && !_disposed) {
        debugPrint('📞 Remote stream received');
        setState(() {});
        _markConnected();
      }
    };

    _webRTCService.onConnected = () {
      if (mounted && !_disposed) {
        debugPrint('📞 ICE Connected');
        _markConnected();
      }
    };

    // ---- SOCKET LISTENERS FOR CALL STATE ----
    _setupSocketListeners();

    // ---- START/JOIN CALL ----

    if (widget.isIncoming) {
      setState(() => _callStatus = 'Connecting...');
      try {
        await _webRTCService.joinCall(
          widget.chatId,
          widget.userId,
          widget.isVideoCall,
        );
        debugPrint('📞 joinCall completed - waiting for offer');
      } catch (e) {
        debugPrint('📞 joinCall error: $e');
        if (mounted && !_disposed) _endCallLocally();
      }
    } else {
      setState(() => _callStatus = 'Ringing...');
      // Emit call:initiate to notify the callee
      socket.emit('call:initiate', {
        'chatId': widget.chatId,
        'type': widget.isVideoCall ? 'video' : 'audio',
        'participants': [widget.userId],
      });

      // Wait for acceptance before starting WebRTC
      // The call:accepted handler will trigger, then we start
      socketService.on('call:accepted', (data) async {
        if (_disposed) return;
        final eventChatId = data is Map ? data['chatId']?.toString() : null;
        if (eventChatId != null && eventChatId != widget.chatId) return;

        debugPrint('📞 Starting WebRTC after call accepted');
        try {
          await _webRTCService.startCall(
            widget.chatId,
            widget.userId,
            widget.isVideoCall,
          );
          debugPrint('📞 startCall completed');
        } catch (e) {
          debugPrint('📞 startCall error: $e');
        }
      });

      // Timeout: if not accepted within 45 seconds, end call
      Future.delayed(const Duration(seconds: 45), () {
        if (mounted && !_isConnected && !_disposed) {
          debugPrint('📞 Call timeout - no answer');
          _endCallLocally();
        }
      });
    }
  }

  void _markConnected() {
    if (!mounted || _isConnected || _disposed) return;
    setState(() {
      _isConnected = true;
      _callStatus = 'Connected';
    });
    _pulseController.stop();
    _startTimer();

    // Explicitly configure audio routing once connected
    if (widget.isVideoCall) {
      Helper.setSpeakerphoneOn(true);
      setState(() => _speakerEnabled = true);
      // Auto-hide controls after 4 seconds for video call
      _startControlsAutoHide();
    } else {
      Helper.setSpeakerphoneOn(false);
      setState(() => _speakerEnabled = false);
    }
  }

  Future<void> _endCallFromRemote() async {
    if (_disposed) return;
    _disposed = true;
    _webRTCService.endCall();

    // Log call unconditionally to ensure history is updated for both parties
    final currentUserId = ref.read(authProvider).user?['_id'] ?? '';
    await ref
        .read(callHistoryProvider.notifier)
        .logCall(
          callerId: widget.isIncoming ? widget.userId : currentUserId,
          receiverId: widget.isIncoming ? currentUserId : widget.userId,
          type: widget.isVideoCall ? 'video' : 'audio',
          status: _isConnected ? 'completed' : 'missed',
          duration: _callDuration,
        );

    // Guarantee UI refreshes instantly
    ref.read(callHistoryProvider.notifier).fetchCallHistory();

    if (mounted) Navigator.pop(context);
  }

  Future<void> _endCallLocally() async {
    if (_disposed) return;
    _disposed = true;

    // Log call unconditionally to ensure history is updated for both parties
    final currentUserId = ref.read(authProvider).user?['_id'] ?? '';
    await ref
        .read(callHistoryProvider.notifier)
        .logCall(
          callerId: widget.isIncoming ? widget.userId : currentUserId,
          receiverId: widget.isIncoming ? currentUserId : widget.userId,
          type: widget.isVideoCall ? 'video' : 'audio',
          status: _isConnected ? 'completed' : 'missed',
          duration: _callDuration,
        );

    // Guarantee UI refreshes instantly
    ref.read(callHistoryProvider.notifier).fetchCallHistory();

    // Emit end event to server so other side gets notified
    final socket = ref.read(socketServiceProvider).socket;
    socket?.emit('call:end', {'chatId': widget.chatId});
    _webRTCService.endCall();
    ref.read(activeCallProvider.notifier).endCall();
    if (mounted) Navigator.pop(context);
  }

  /// Minimize call — keep WebRTC alive, show green banner
  void _minimizeCall() {
    if (_disposed) return;
    _minimized = true;
    ref
        .read(activeCallProvider.notifier)
        .setActiveCall(
          chatId: widget.chatId,
          userId: widget.userId,
          callerName: widget.callerName,
          callerAvatar: widget.callerAvatar,
          isVideoCall: widget.isVideoCall,
          isIncoming: widget.isIncoming,
          currentDuration: _callDuration,
        );
    if (mounted) Navigator.pop(context);
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleControls() {
    if (!widget.isVideoCall || !_isConnected) return;
    if (_showControls) {
      _hideControls();
    } else {
      _showControlsWithTimer();
    }
  }

  void _showControlsWithTimer() {
    _controlsTimer?.cancel();
    setState(() => _showControls = true);
    _controlsAnimController.forward();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && _isConnected && widget.isVideoCall) {
        _hideControls();
      }
    });
  }

  void _hideControls() {
    _controlsTimer?.cancel();
    _controlsAnimController.reverse().then((_) {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _startControlsAutoHide() {
    if (!widget.isVideoCall || !_isConnected) return;
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && _isConnected) {
        _hideControls();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _callTimer?.cancel();
    _controlsTimer?.cancel();
    _pulseController.dispose();
    _controlsAnimController.dispose();

    // Clean up call-specific socket listeners
    final socketService = ref.read(socketServiceProvider);
    socketService.off('call:ended');
    socketService.off('call:accepted');
    socketService.off('call:rejected');
    socketService.off('call:hangup');
    socketService.off('call:end');

    // Only end the actual WebRTC call if NOT being minimized
    if (!_minimized) {
      _webRTCService.endCall();
    }
    super.dispose();
  }

  void _toggleMic() {
    setState(() => _micEnabled = !_micEnabled);
    final localStream = _webRTCService.localRenderer.srcObject;
    if (localStream != null) {
      for (final track in localStream.getAudioTracks()) {
        track.enabled = _micEnabled;
      }
    }
  }

  void _toggleSpeaker() {
    setState(() => _speakerEnabled = !_speakerEnabled);
    Helper.setSpeakerphoneOn(_speakerEnabled);
  }

  void _toggleVideo() {
    setState(() => _videoEnabled = !_videoEnabled);
    final localStream = _webRTCService.localRenderer.srcObject;
    if (localStream != null) {
      for (final track in localStream.getVideoTracks()) {
        track.enabled = _videoEnabled;
      }
    }
  }

  void _switchCamera() {
    final localStream = _webRTCService.localRenderer.srcObject;
    if (localStream != null) {
      final videoTracks = localStream.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        Helper.switchCamera(videoTracks.first);
      }
    }
  }

  // Whether we're in video-connected mode (fullscreen video, minimal UI)
  bool get _isVideoConnected => widget.isVideoCall && _isConnected;

  @override
  Widget build(BuildContext context) {
    final avatar = UrlUtils.getFullUrl(widget.callerAvatar ?? '');

    return Scaffold(
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ── Background ──
            if (_isVideoConnected) ...[
              // Remote Video (Full Screen)
              Positioned.fill(
                child: RTCVideoView(
                  _webRTCService.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ] else ...[
              // Gradient Background for audio call or connecting state
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0D1B2A),
                        Color(0xFF1B2838),
                        Color(0xFF0A1628),
                      ],
                    ),
                  ),
                ),
              ),
              // Decorative circles
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentBlue.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: 100,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentBlue.withValues(alpha: 0.03),
                  ),
                ),
              ),
            ],

            // Hidden renderer for audio routing
            if (!widget.isVideoCall && _isConnected)
              Positioned(
                left: -10,
                top: -10,
                width: 1,
                height: 1,
                child: RTCVideoView(_webRTCService.remoteRenderer),
              ),

            // ── VIDEO CALL CONNECTED: Minimal overlay UI ──
            if (_isVideoConnected) ...[
              // Top bar with name (always visible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: _isConnected
                                ? _minimizeCall
                                : _endCallLocally,
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.callerName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatDuration(_callDuration),
                                  style: TextStyle(
                                    color: Colors.green.shade300,
                                    fontSize: 12.sp,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Encrypted',
                                  style: TextStyle(
                                    color: Colors.green.shade300,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Local Video (small overlay, bottom-right above controls)
              if (_videoEnabled)
                Positioned(
                  right: 16.w,
                  bottom: _showControls ? 200.h : 24.h,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 100.w,
                        height: 140.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: RTCVideoView(
                          _webRTCService.localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                  ),
                ),

              // Bottom controls with slide + fade animation
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: _controlsSlideAnimation,
                  child: FadeTransition(
                    opacity: _controlsFadeAnimation,
                    child: Container(
                      padding: EdgeInsets.only(
                        left: 24.w,
                        right: 24.w,
                        top: 20.h,
                        bottom: MediaQuery.of(context).padding.bottom + 16.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _CallActionButton(
                                icon: _micEnabled ? Icons.mic : Icons.mic_off,
                                label: _micEnabled ? 'Mute' : 'Unmute',
                                isActive: !_micEnabled,
                                onTap: () {
                                  _toggleMic();
                                  _startControlsAutoHide();
                                },
                              ),
                              _CallActionButton(
                                icon: _speakerEnabled
                                    ? Icons.volume_up
                                    : Icons.volume_off,
                                label: 'Speaker',
                                isActive: _speakerEnabled,
                                onTap: () {
                                  _toggleSpeaker();
                                  _startControlsAutoHide();
                                },
                              ),
                              _CallActionButton(
                                icon: _videoEnabled
                                    ? Icons.videocam
                                    : Icons.videocam_off,
                                label: 'Video',
                                isActive: !_videoEnabled,
                                onTap: () {
                                  _toggleVideo();
                                  _startControlsAutoHide();
                                },
                              ),
                              _CallActionButton(
                                icon: Icons.switch_camera,
                                label: 'Flip',
                                onTap: () {
                                  _switchCamera();
                                  _startControlsAutoHide();
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 24.h),
                          GestureDetector(
                            onTap: _endCallLocally,
                            child: Container(
                              width: 64.r,
                              height: 64.r,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 30.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]
            // ── AUDIO CALL / CONNECTING: Standard centered layout ──
            else
              SafeArea(
                child: Column(
                  children: [
                    // Top bar
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: _isConnected
                                ? _minimizeCall
                                : _endCallLocally,
                          ),
                          const Spacer(),
                          if (_isConnected)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Encrypted',
                                    style: TextStyle(
                                      color: Colors.green.shade300,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Caller info centered
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Avatar with pulse animation
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _isConnected
                                    ? 1.0
                                    : _pulseAnimation.value,
                                child: child,
                              );
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (!_isConnected) ...[
                                  Container(
                                    width: 140.r,
                                    height: 140.r,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.accentBlue.withValues(
                                          alpha: 0.15,
                                        ),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 165.r,
                                    height: 165.r,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.accentBlue.withValues(
                                          alpha: 0.08,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ],
                                CircleAvatar(
                                  radius: 55.r,
                                  backgroundColor: AppColors.accentBlue
                                      .withValues(alpha: 0.3),
                                  backgroundImage: avatar.isNotEmpty
                                      ? CachedNetworkImageProvider(avatar)
                                      : null,
                                  child: avatar.isEmpty
                                      ? Text(
                                          widget.callerName.isNotEmpty
                                              ? widget.callerName[0]
                                                    .toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 36.sp,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 24.h),

                          Text(
                            widget.callerName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),

                          SizedBox(height: 8.h),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _isConnected
                                  ? _formatDuration(_callDuration)
                                  : _callStatus,
                              key: ValueKey(
                                _isConnected ? _callDuration : _callStatus,
                              ),
                              style: TextStyle(
                                color: _isConnected
                                    ? Colors.green.shade300
                                    : Colors.white70,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w400,
                                letterSpacing: _isConnected ? 2 : 0,
                              ),
                            ),
                          ),

                          SizedBox(height: 4.h),

                          Text(
                            widget.isVideoCall ? 'Video Call' : 'Voice Call',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons (always visible for audio/connecting)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 20.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _CallActionButton(
                                icon: _micEnabled ? Icons.mic : Icons.mic_off,
                                label: _micEnabled ? 'Mute' : 'Unmute',
                                isActive: !_micEnabled,
                                onTap: _toggleMic,
                              ),
                              _CallActionButton(
                                icon: _speakerEnabled
                                    ? Icons.volume_up
                                    : Icons.volume_off,
                                label: 'Speaker',
                                isActive: _speakerEnabled,
                                onTap: _toggleSpeaker,
                              ),
                              if (widget.isVideoCall)
                                _CallActionButton(
                                  icon: _videoEnabled
                                      ? Icons.videocam
                                      : Icons.videocam_off,
                                  label: 'Video',
                                  isActive: !_videoEnabled,
                                  onTap: _toggleVideo,
                                ),
                              if (widget.isVideoCall)
                                _CallActionButton(
                                  icon: Icons.switch_camera,
                                  label: 'Flip',
                                  onTap: _switchCamera,
                                ),
                            ],
                          ),

                          SizedBox(height: 24.h),

                          GestureDetector(
                            onTap: _endCallLocally,
                            child: Container(
                              width: 64.r,
                              height: 64.r,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 30.sp,
                              ),
                            ),
                          ),

                          SizedBox(height: 16.h),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52.r,
            height: 52.r,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.8),
              size: 24.sp,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(color: Colors.white70, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}
