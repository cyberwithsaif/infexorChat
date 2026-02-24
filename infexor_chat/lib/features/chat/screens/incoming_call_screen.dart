import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/socket_service.dart';
import '../providers/call_history_provider.dart';
import 'call_screen.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String chatId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.chatId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    this.isVideo = true,
  });

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  bool _handled = false;
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    _playRingtone();
    _startVibration();

    // Listen for caller cancellation (caller hangs up before we answer)
    final socketService = ref.read(socketServiceProvider);
    socketService.on('call:ended', _onCallCancelled);
    socketService.on('call:end', _onCallCancelled);
  }

  void _startVibration() {
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) {
      if (!_handled) {
        HapticFeedback.vibrate();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _playRingtone() async {
    try {
      final player = FlutterRingtonePlayer();
      player.play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.electronic,
        looping: true,
        volume: 1.0,
        asAlarm: false,
      );
      debugPrint('🔔 Ringtone started via FlutterRingtonePlayer.play');
    } catch (e) {
      debugPrint('🔔 Ringtone play error: $e');
      // Fallback: try notification sound
      try {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.notification,
          ios: IosSounds.receivedMessage,
          looping: true,
          volume: 1.0,
        );
      } catch (e2) {
        debugPrint('🔔 Fallback ringtone also failed: $e2');
      }
    }
  }

  Future<void> _stopRingtone() async {
    try {
      FlutterRingtonePlayer().stop();
      debugPrint('🔔 Ringtone stopped');
    } catch (_) {}
  }

  void _onCallCancelled(dynamic _) {
    debugPrint('📞 Caller cancelled/ended the call');
    if (mounted && !_handled) {
      _handled = true;
      _stopRingtone();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _handled = true;
    _vibrationTimer?.cancel();
    _stopRingtone();
    final socketService = ref.read(socketServiceProvider);
    socketService.off('call:ended');
    socketService.off('call:end');
    super.dispose();
  }

  void _acceptCall() {
    if (_handled) return;
    _handled = true;
    _stopRingtone();
    ref.read(socketServiceProvider).socket?.emit('call:accept', {
      'chatId': widget.chatId,
      'callerId': widget.callerId,
    });
    Navigator.pushReplacement(
      context,
      ScaleFadePageRoute(
        builder: (_) => CallPage(
          chatId: widget.chatId,
          userId: widget.callerId,
          callerName: widget.callerName,
          callerAvatar: widget.callerAvatar,
          isVideoCall: widget.isVideo,
          isIncoming: true,
        ),
      ),
    );
  }

  void _declineCall() {
    if (_handled) return;
    _handled = true;
    _stopRingtone();
    ref.read(socketServiceProvider).socket?.emit('call:reject', {
      'chatId': widget.chatId,
      'callerId': widget.callerId,
    });

    final currentUserId = ref.read(authProvider).user?['_id']?.toString() ?? '';

    // Log as a declined/missed call
    ref
        .read(callHistoryProvider.notifier)
        .logCall(
          callerId: widget.callerId,
          receiverId: currentUserId,
          type: widget.isVideo ? 'video' : 'audio',
          status: 'declined',
          duration: 0,
        );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = UrlUtils.getFullUrl(widget.callerAvatar ?? '');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF162640), Color(0xFF0A1628)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative background elements
              Positioned(
                top: -80,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentBlue.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: 50,
                right: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentBlue.withValues(alpha: 0.03),
                  ),
                ),
              ),

              // Main content
              Column(
                children: [
                  SizedBox(height: 20.h),

                  // Call type badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isVideo ? Icons.videocam : Icons.call,
                          color: AppColors.accentBlue,
                          size: 16.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Incoming ${widget.isVideo ? "Video" : "Voice"} Call',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Avatar with animated rings
                  _AnimatedRings(
                    child: CircleAvatar(
                      radius: 60.r,
                      backgroundColor: AppColors.accentBlue.withValues(
                        alpha: 0.3,
                      ),
                      backgroundImage: avatar.isNotEmpty
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? Text(
                              widget.callerName.isNotEmpty
                                  ? widget.callerName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 40.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                  ),

                  SizedBox(height: 28.h),

                  // Caller name
                  Text(
                    widget.callerName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Status text
                  Text(
                    'Infexor ${widget.isVideo ? 'Video' : 'Voice'} Call',
                    style: TextStyle(color: Colors.white38, fontSize: 14.sp),
                  ),

                  const Spacer(flex: 3),

                  // Action buttons
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Decline
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _declineCall,
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
                                  size: 28.sp,
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'Decline',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),

                        // Accept
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _acceptCall,
                              child: Container(
                                width: 64.r,
                                height: 64.r,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.isVideo ? Icons.videocam : Icons.call,
                                  color: Colors.white,
                                  size: 28.sp,
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'Accept',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 48.h),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedRings extends StatefulWidget {
  final Widget child;
  const _AnimatedRings({required this.child});

  @override
  State<_AnimatedRings> createState() => _AnimatedRingsState();
}

class _AnimatedRingsState extends State<_AnimatedRings>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _ring1;
  late Animation<double> _ring2;
  late Animation<double> _ring3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _ring1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _ring2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.85, curve: Curves.easeOut),
      ),
    );
    _ring3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildRing(Animation<double> animation, double baseSize) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Container(
          width: baseSize + (40 * animation.value),
          height: baseSize + (40 * animation.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accentBlue.withValues(
                alpha: 0.3 * (1 - animation.value),
              ),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200.r,
      height: 200.r,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildRing(_ring1, 120.r),
          _buildRing(_ring2, 120.r),
          _buildRing(_ring3, 120.r),
          widget.child,
        ],
      ),
    );
  }
}
