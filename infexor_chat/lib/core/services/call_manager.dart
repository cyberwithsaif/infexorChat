import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hive_flutter/hive_flutter.dart';
import '../../config/routes.dart';
import '../../features/chat/services/socket_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/auth_service.dart';
import '../providers/active_call_provider.dart';
import 'webrtc_service.dart';

// ─── iOS VoIP native ↔ Flutter channel ──────────────────────────────────────
// Mirrors AppDelegate.voipChannelName in Swift.
// Receives: onVoipToken, onCallBusy events FROM native.
// Sends:    endCall, getVoipToken calls TO native.
const MethodChannel _callsChannel = MethodChannel(
  'com.infexor.infexor_chat/calls',
);
const MethodChannel _voipChannel = MethodChannel(
  'com.infexor.infexor_chat/voip',
);

/// Holds data about the currently ringing incoming call (foreground socket path).
/// null when no call is ringing. Chat list watches this to show a ringing badge.
class IncomingCallNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;

  void setCall(Map<String, dynamic>? data) => state = data;
}

final incomingCallProvider =
    NotifierProvider<IncomingCallNotifier, Map<String, dynamic>?>(
      IncomingCallNotifier.new,
    );

/// Whether the app is currently in native Android PiP mode.
class PipModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final pipModeProvider = NotifierProvider<PipModeNotifier, bool>(
  PipModeNotifier.new,
);

final callManagerProvider = Provider<CallManager>((ref) {
  return CallManager(ref);
});

class CallManager {
  final Ref _ref;
  bool _initialized = false;
  bool _isShowingIncomingCall = false;

  CallManager(this._ref);

  // ─── Public entry point ──────────────────────────────────────────────────

  void init() {
    if (_initialized) return;
    _initialized = true;

    _callsChannel.setMethodCallHandler(_handleNativeCallEvent);
    _checkKilledStateCall();
    _registerSocketCallHandlers();
    if (Platform.isIOS) _setupIOSVoipChannel();
  }

  // ─── iOS: native → Flutter channel ───────────────────────────────────────

  void _setupIOSVoipChannel() {
    _voipChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onVoipToken':
          // AppDelegate got a fresh PushKit token → send to backend
          final token = (call.arguments as Map?)?['token']?.toString() ?? '';
          if (token.isNotEmpty) {
            debugPrint(
              '📱 iOS VoIP token received: ${token.substring(0, 8)}...',
            );
            try {
              await _ref.read(authServiceProvider).registerVoipToken(token);
            } catch (e) {
              debugPrint('📱 Failed to register VoIP token: $e');
            }
          }
          break;

        case 'onCallBusy':
          // AppDelegate received a call_busy VoIP push (native path for killed app)
          final data = call.arguments as Map<dynamic, dynamic>? ?? {};
          final chatId = data['chatId']?.toString() ?? '';
          debugPrint('📞 iOS call:busy received (native) — chatId: $chatId');
          // Show snackbar BEFORE the async endCall gap
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('User is busy on another call'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          if (chatId.isNotEmpty) {
            await _callsChannel.invokeMethod('endCall', {'chatId': chatId});
          }
          break;

        default:
          break;
      }
    });
  }

  // ─── Callkit event dispatcher ────────────────────────────────────────────

  Future<void> _handleNativeCallEvent(MethodCall call) async {
    if (call.method == 'onCallEvent') {
      final args = call.arguments as Map<dynamic, dynamic>? ?? {};
      final action = args['action']?.toString();
      debugPrint('📞 Native call event: $action');

      switch (action) {
        case 'accept':
          _onCallkitAccept(args);
          break;
        case 'reject':
          _onCallkitDecline(args);
          break;
        case 'ring':
          _onCallkitRing(args);
          break;
        case 'resume':
          _onCallResume();
          break;
      }
    } else if (call.method == 'onPiPChanged') {
      final isInPiP = (call.arguments as Map?)?['isInPiP'] == true;
      debugPrint('📞 PiP mode changed: $isInPiP');
      _ref.read(pipModeProvider.notifier).set(isInPiP);
    }
  }

  // ─── Accept ──────────────────────────────────────────────────────────────

  void _onCallkitAccept(Map<dynamic, dynamic> body) {
    final chatId = body['callId']?.toString() ?? '';
    final callerId = body['callerId']?.toString() ?? '';
    final callerName = body['callerName']?.toString() ?? 'Unknown';
    final callerAvatar = body['callerAvatar']?.toString();
    final isVideo = body['isVideo']?.toString() == 'true';

    if (chatId.isEmpty) return;

    debugPrint(
      '📞 Callkit accepted — chatId: $chatId (showing=$_isShowingIncomingCall)',
    );

    // If Flutter IncomingCallScreen is already showing (socket foreground path),
    // dismiss it first, then navigate to CallPage.
    if (_isShowingIncomingCall) {
      debugPrint('📞 Dismissing existing IncomingCallScreen before accepting');
      _ref.read(incomingCallProvider.notifier).setCall(null);
      final nav = navigatorKey.currentState;
      if (nav != null && nav.canPop()) nav.pop();
    }

    _isShowingIncomingCall = true;

    // Stop the native ringing notification/service
    _callsChannel.invokeMethod('endCall', {'chatId': chatId});

    _pushCallPageWhenReady(
      chatId: chatId,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      isVideo: isVideo,
    );
  }

  // ─── Wait for navigator then push CallPage ───────────────────────────────

  Future<void> _pushCallPageWhenReady({
    required String chatId,
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required bool isVideo,
  }) async {
    const maxWaitMs = 12000;
    const pollMs = 150;
    int waited = 0;

    // Wait until navigator is ready, auth is done, AND splash redirect has
    // completed (route is no longer /splash).
    while (waited < maxWaitMs) {
      if (navigatorKey.currentState != null) {
        final authStatus = _ref.read(authProvider).status;
        if (authStatus == AuthStatus.authenticated) {
          final currentLocation =
              router.routeInformationProvider.value.uri.path;
          if (currentLocation != '/splash') break;
        }
      }
      await Future.delayed(const Duration(milliseconds: pollMs));
      waited += pollMs;
    }

    if (navigatorKey.currentState == null) {
      debugPrint('📞 Navigator never became ready — cannot open CallPage');
      _isShowingIncomingCall = false;
      return;
    }

    // Extra settle frame so context.go('/home') fully completes
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint(
      '📞 System ready after ${waited}ms — pushing CallPage via GoRouter',
    );
    router.push(
      '/call',
      extra: {
        'chatId': chatId,
        'userId': callerId,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'isVideoCall': isVideo,
        'isIncoming': true,
        'callkitAccepted': true,
      },
    );
    _isShowingIncomingCall = false;
  }

  // ─── Decline ─────────────────────────────────────────────────────────────

  void _onCallkitDecline(Map<dynamic, dynamic> body) {
    final chatId = body['callId']?.toString() ?? '';
    final callerId = body['callerId']?.toString() ?? '';

    debugPrint(
      '📞 Callkit declined — chatId: $chatId (showing=$_isShowingIncomingCall)',
    );

    // If Flutter IncomingCallScreen is already showing (socket foreground path),
    // dismiss it first.
    if (_isShowingIncomingCall) {
      debugPrint('📞 Dismissing existing IncomingCallScreen before declining');
      _ref.read(incomingCallProvider.notifier).setCall(null);
      final nav = navigatorKey.currentState;
      if (nav != null && nav.canPop()) nav.pop();
    }

    _isShowingIncomingCall = false;

    // Stop the native ringing notification/service
    _callsChannel.invokeMethod('endCall', {'chatId': chatId});

    _emitRejectWhenSocketReady(chatId, callerId);
  }

  /// Wait for socket to connect, then emit call:reject.
  /// Needed because reject from notification can happen before socket is ready
  /// (app was killed/background when FCM arrived).
  Future<void> _emitRejectWhenSocketReady(
    String chatId,
    String callerId,
  ) async {
    final socketService = _ref.read(socketServiceProvider);

    // If already connected, emit immediately
    if (socketService.isConnected && socketService.socket != null) {
      socketService.socket!.emit('call:reject', {
        'chatId': chatId,
        'callerId': callerId,
      });
      debugPrint('📞 Emitted call:reject immediately');
      return;
    }

    // Wait up to 10 seconds for socket to connect
    debugPrint('📞 Socket not ready — waiting to emit call:reject');
    const maxWaitMs = 10000;
    const pollMs = 300;
    int waited = 0;

    while (waited < maxWaitMs) {
      await Future.delayed(const Duration(milliseconds: pollMs));
      waited += pollMs;
      if (socketService.isConnected && socketService.socket != null) {
        socketService.socket!.emit('call:reject', {
          'chatId': chatId,
          'callerId': callerId,
        });
        debugPrint('📞 Emitted call:reject after ${waited}ms');
        return;
      }
    }
    debugPrint('📞 Socket never connected — call:reject not sent');
  }

  // ─── Resume (ongoing call notification tapped) ─────────────────────────

  void _onCallResume() {
    final activeCall = _ref.read(activeCallProvider);
    if (!activeCall.isActive) {
      debugPrint('📞 Resume requested but no active call');
      return;
    }

    debugPrint('📞 Resuming call from notification tap');
    _ref.read(activeCallProvider.notifier).clearActiveCall();
    router.push(
      '/call',
      extra: {
        'chatId': activeCall.chatId,
        'userId': activeCall.userId,
        'callerName': activeCall.callerName,
        'callerAvatar': activeCall.callerAvatar,
        'isVideoCall': activeCall.isVideoCall,
        'isIncoming': activeCall.isIncoming,
        'isResuming': true,
        'initialDuration': activeCall.duration,
      },
    );
  }

  // ─── Ring (notification body tapped) ───────────────────────────────────

  void _onCallkitRing(Map<dynamic, dynamic> body) {
    final chatId = body['callId']?.toString() ?? '';
    final callerId = body['callerId']?.toString() ?? '';
    final callerName = body['callerName']?.toString() ?? 'Unknown';
    final callerAvatar = body['callerAvatar']?.toString();
    final isVideo = body['isVideo']?.toString() == 'true';

    if (chatId.isEmpty) return;
    if (_isShowingIncomingCall) return;

    // Don't show ringing UI if we're already on a call (stale notification tap)
    if (WebRTCService().isCallActive) {
      debugPrint('📞 Ignoring ring — already on an active call');
      _callsChannel.invokeMethod('endCall', {'chatId': chatId});
      return;
    }

    debugPrint(
      '📞 Callkit ring — showing IncomingCallScreen for chatId: $chatId',
    );
    _isShowingIncomingCall = true;

    _ref.read(incomingCallProvider.notifier).setCall({
      'chatId': chatId,
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'isVideo': isVideo,
    });

    _pushIncomingCallWhenReady(
      chatId: chatId,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      isVideo: isVideo,
    );
  }

  // ─── Wait for navigator then push IncomingCallScreen ───────────────────

  Future<void> _pushIncomingCallWhenReady({
    required String chatId,
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required bool isVideo,
  }) async {
    const maxWaitMs = 12000;
    const pollMs = 150;
    int waited = 0;

    // Wait until navigator is ready, auth is done, AND splash redirect has
    // completed.  Without the location check there is a race: the push can
    // land while the stack is still at /splash, and the subsequent
    // context.go('/home') wipes the entire stack — destroying the screen.
    while (waited < maxWaitMs) {
      if (navigatorKey.currentState != null) {
        final authStatus = _ref.read(authProvider).status;
        if (authStatus == AuthStatus.authenticated) {
          // Ensure splash redirect to /home has settled
          final currentLocation =
              router.routeInformationProvider.value.uri.path;
          if (currentLocation != '/splash') break;
        }
      }
      await Future.delayed(const Duration(milliseconds: pollMs));
      waited += pollMs;
    }

    if (navigatorKey.currentState == null) {
      debugPrint(
        '📞 Navigator never became ready — cannot open IncomingCallScreen',
      );
      _isShowingIncomingCall = false;
      _ref.read(incomingCallProvider.notifier).setCall(null);
      return;
    }

    // Extra settle frame so context.go('/home') fully completes
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint(
      '📞 System ready after ${waited}ms — pushing IncomingCallScreen',
    );
    router
        .push(
          '/incoming-call',
          extra: {
            'callId': 'call_$chatId',
            'chatId': chatId,
            'callerId': callerId,
            'callerName': callerName,
            'callerAvatar': callerAvatar,
            'isVideo': isVideo,
          },
        )
        .then((_) {
          _isShowingIncomingCall = false;
          _ref.read(incomingCallProvider.notifier).setCall(null);
        });
  }

  // ─── Killed-state recovery ───────────────────────────────────────────────
  //
  // When the app is killed and the user taps Accept on the callkit UI,
  // Android launches the Flutter engine. The onEvent stream delivers
  // Event.actionCallAccept almost immediately (<300ms), so _isShowingIncomingCall
  // is set before this function's 1.8s wait completes and the function returns.
  //
  // If activeCalls() returns entries but no Accept event fired within 1.8s,
  // those entries are stale (left over from a force-close during a previous call)
  // and are cleared with endAllCalls() so they don't re-open on every launch.

  Future<void> _checkKilledStateCall() async {
    // Retry getPendingCall in a poll loop to handle the race condition where
    // handleIntent() in Kotlin hasn't stored the pending call data yet when
    // Flutter's CallManager.init() fires during a cold start from notification.
    const maxAttempts = 10; // 10 × 300ms = 3 seconds
    const pollMs = 300;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final pendingRaw = await _callsChannel.invokeMethod('getPendingCall');
        if (pendingRaw is Map) {
          final pending = Map<dynamic, dynamic>.from(pendingRaw);
          final action = pending['action']?.toString();
          debugPrint(
            '📞 getPendingCall returned action=$action (attempt $attempt)',
          );
          if (action == 'accept') {
            _onCallkitAccept(pending);
          } else if (action == 'reject') {
            _onCallkitDecline(pending);
          } else if (action == 'ring') {
            _onCallkitRing(pending);
          }
          return; // Successfully handled
        }
      } catch (e) {
        debugPrint('📞 _checkKilledStateCall error (attempt $attempt): $e');
      }
      // Only retry if this is a cold start (no active call showing yet)
      if (_isShowingIncomingCall) return;
      await Future.delayed(const Duration(milliseconds: pollMs));
    }
    debugPrint('📞 No pending call found after $maxAttempts attempts');
  }

  // ─── Socket handlers (foreground) ────────────────────────────────────────

  void _registerSocketCallHandlers() {
    final socketService = _ref.read(socketServiceProvider);

    // ─── Caller cancelled before we answered ─────────────────────────────
    socketService.on('call:cancelled', (data) {
      if (data is! Map<String, dynamic>) return;
      final chatId = data['chatId']?.toString() ?? '';
      debugPrint('📞 call:cancelled received — chatId: $chatId');

      // Dismiss the native ringing notification/service
      if (chatId.isNotEmpty) {
        _callsChannel.invokeMethod('endCall', {'chatId': chatId});
      }

      // Only pop IncomingCallScreen if we are actually showing one
      // and the chatId matches the current incoming call.
      if (_isShowingIncomingCall) {
        final currentCall = _ref.read(incomingCallProvider);
        final currentChatId = currentCall?['chatId']?.toString() ?? '';
        if (chatId.isEmpty || chatId == currentChatId) {
          _isShowingIncomingCall = false;
          _ref.read(incomingCallProvider.notifier).setCall(null);
          final nav = navigatorKey.currentState;
          if (nav != null && nav.canPop()) nav.pop();
        }
      }
    });

    // ─── Receiver is busy on another call ────────────────────────────────
    socketService.on('call:busy', (data) {
      if (data is! Map<String, dynamic>) return;
      final chatId = data['chatId']?.toString() ?? '';
      debugPrint('📞 call:busy received — chatId: $chatId');

      // Dismiss callkit if showing (shouldn't normally be visible for the
      // caller, but end it just in case)
      if (chatId.isNotEmpty) {
        _callsChannel.invokeMethod('endCall', {'chatId': chatId});
      }

      // Show a brief "User is busy" snackbar
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('User is busy on another call'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    // ─── Remote ended the call (global handler for minimized calls) ─────
    // CallPage registers its own call:ended listener but removes it on
    // dispose (when minimized). This global listener catches the event
    // when the call is minimized (green banner showing) so the WebRTC
    // connection and banner are properly torn down.
    for (final event in ['call:ended', 'call:end', 'call:hangup']) {
      socketService.on(event, (data) {
        if (data is! Map<String, dynamic>) return;
        final chatId = data['chatId']?.toString() ?? '';
        final activeCall = _ref.read(activeCallProvider);
        if (activeCall.isActive && activeCall.chatId == chatId) {
          debugPrint('📞 $event received while minimized — ending call');
          WebRTCService().endCall();
          _ref.read(activeCallProvider.notifier).endCall();
          _callsChannel.invokeMethod('hideOngoingCallNotification');
        }
      });
    }

    // ─── Foreground incoming call via socket ──────────────────────────────
    socketService.on('call:incoming', (data) {
      if (data is! Map<String, dynamic>) return;
      if (_isShowingIncomingCall) {
        debugPrint('📞 Ignoring duplicate call:incoming (already showing)');
        return;
      }

      final chatId = data['chatId']?.toString() ?? '';
      final callerId = data['callerId']?.toString() ?? '';
      final type = data['type']?.toString() ?? 'audio';

      // Busy check — auto-decline if already on a call
      if (WebRTCService().isCallActive) {
        debugPrint('📞 Busy — rejecting call');
        socketService.socket?.emit('call:busy', {
          'chatId': chatId,
          'callerId': callerId,
        });
        return;
      }

      final callerName = _resolveCallerName(data, callerId);
      final callerAvatar = _resolveCallerAvatar(data);

      _isShowingIncomingCall = true;

      // Expose call data so chat list can show a ringing indicator
      _ref.read(incomingCallProvider.notifier).setCall({
        'chatId': chatId,
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'isVideo': type == 'video',
      });

      router
          .push(
            '/incoming-call',
            extra: {
              'callId': 'call_$chatId',
              'chatId': chatId,
              'callerId': callerId,
              'callerName': callerName,
              'callerAvatar': callerAvatar,
              'isVideo': type == 'video',
            },
          )
          .then((_) {
            _isShowingIncomingCall = false;
            _ref.read(incomingCallProvider.notifier).setCall(null);
          });
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _resolveCallerName(Map<String, dynamic> data, String callerId) {
    String name = 'Unknown';

    final callerData = data['caller'] ?? data['callerInfo'];
    if (callerData is Map) {
      name = callerData['name']?.toString() ?? 'Unknown';
    }
    if (name == 'Unknown') name = data['callerName']?.toString() ?? 'Unknown';

    if (name == 'Unknown' && callerId.isNotEmpty) {
      try {
        if (Hive.isBoxOpen('contacts_cache')) {
          final saved = Hive.box('contacts_cache').get(callerId);
          if (saved != null && saved.toString().isNotEmpty) {
            name = saved.toString();
          }
        }
      } catch (_) {}
    }

    if (name == 'Unknown' && callerId.isNotEmpty) {
      try {
        if (Hive.isBoxOpen('user_names_cache')) {
          final cached = Hive.box('user_names_cache').get(callerId);
          if (cached is Map) name = cached['name']?.toString() ?? 'Unknown';
        }
      } catch (_) {}
    }

    if (name == 'Unknown') {
      final phone = data['callerPhone']?.toString();
      if (phone != null && phone.isNotEmpty) name = phone;
    }

    return name;
  }

  String? _resolveCallerAvatar(Map<String, dynamic> data) {
    final callerData = data['caller'] ?? data['callerInfo'];
    if (callerData is Map) return callerData['avatar']?.toString();
    return data['callerAvatar']?.toString();
  }

  void dispose() {
    // Clean up if needed
  }
}
