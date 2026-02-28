import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/routes.dart';
import '../utils/animated_page_route.dart';
import '../../features/chat/screens/incoming_call_screen.dart';
import '../../features/chat/screens/call_screen.dart';
import '../../features/chat/services/socket_service.dart';
import '../../features/auth/services/auth_service.dart';
import 'webrtc_service.dart';

// ─── iOS VoIP native ↔ Flutter channel ──────────────────────────────────────
// Mirrors AppDelegate.voipChannelName in Swift.
// Receives: onVoipToken, onCallBusy events FROM native.
// Sends:    endCall, getVoipToken calls TO native.
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

final callManagerProvider = Provider<CallManager>((ref) {
  return CallManager(ref);
});

class CallManager {
  final Ref _ref;
  bool _initialized = false;
  bool _isShowingIncomingCall = false;
  StreamSubscription<CallEvent?>? _callkitSub;

  CallManager(this._ref);

  // ─── Public entry point ──────────────────────────────────────────────────

  void init() {
    if (_initialized) return;
    _initialized = true;

    // 1. Register callkit event listener first so we don't miss events that
    //    arrive while the rest of init is running.
    _callkitSub = FlutterCallkitIncoming.onEvent.listen(
      _handleCallkitEvent,
      onError: (e) => debugPrint('📞 CallManager callkit error: $e'),
    );

    // 2. Check for a call that was accepted while the app was killed.
    _checkKilledStateCall();

    // 3. Socket handler for foreground incoming calls.
    _registerSocketCallHandlers();

    // 4. iOS only — listen for events coming FROM AppDelegate via method channel.
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
            await FlutterCallkitIncoming.endCall(chatId);
          }
          break;

        default:
          break;
      }
    });
  }

  // ─── Callkit event dispatcher ────────────────────────────────────────────

  void _handleCallkitEvent(CallEvent? event) {
    if (event == null) return;
    debugPrint('📞 Callkit event: ${event.event}');

    switch (event.event) {
      case Event.actionCallAccept:
        _onCallkitAccept(event.body as Map<String, dynamic>? ?? {});
        break;

      case Event.actionCallDecline:
        _onCallkitDecline(event.body as Map<String, dynamic>? ?? {});
        break;

      case Event.actionCallEnded:
        _onCallkitEndedOrTimeout(event.body as Map<String, dynamic>? ?? {});
        break;

      case Event.actionCallTimeout:
        // Callkit timed out — treat as a decline so the server knows
        _onCallkitTimeout(event.body as Map<String, dynamic>? ?? {});
        break;

      default:
        break;
    }
  }

  // ─── Accept ──────────────────────────────────────────────────────────────

  void _onCallkitAccept(Map<String, dynamic> body) {
    final extra = _extra(body);
    final chatId = extra['chatId']?.toString() ?? body['id']?.toString() ?? '';
    final callerId = extra['callerId']?.toString() ?? '';
    final callerName =
        extra['callerName']?.toString() ??
        body['nameCaller']?.toString() ??
        'Unknown';
    final callerAvatar = extra['callerAvatar']?.toString();
    final isVideo = extra['isVideo'] == 'true';

    if (chatId.isEmpty) return;

    debugPrint('📞 Callkit accepted — chatId: $chatId');
    _isShowingIncomingCall = true; // block duplicate socket handler

    // NOTE: call:accept is NOT emitted here because the socket may not be
    // connected yet (killed-state launch). CallPage emits it after the socket
    // is confirmed ready (callkitAccepted: true tells CallPage to do this).

    // Navigate to the active call screen.
    // On cold-start (killed state) the GoRouter walks through /splash auth
    // checks before mounting its navigator, so navigatorKey.currentState is
    // null for several seconds. Poll until it is ready.
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
    // GoRouter walks through /splash auth checks on cold-start, so the
    // navigator can be null for several seconds. Poll until it is ready.
    const maxWaitMs = 12000;
    const pollMs = 150;
    int waited = 0;

    // Wait until GoRouter's navigator is mounted. On cold start, the router
    // goes through /splash → auth check → /home, so it can take a few seconds.
    while (navigatorKey.currentState == null && waited < maxWaitMs) {
      await Future.delayed(const Duration(milliseconds: pollMs));
      waited += pollMs;
    }

    if (navigatorKey.currentState == null) {
      debugPrint('📞 Navigator never became ready — cannot open CallPage');
      _isShowingIncomingCall = false;
      return;
    }

    debugPrint('📞 Navigator ready after ${waited}ms — pushing CallPage');
    navigatorKey.currentState!
        .push(
          ScaleFadePageRoute(
            builder: (_) => CallPage(
              chatId: chatId,
              userId: callerId,
              callerName: callerName,
              callerAvatar: callerAvatar,
              isVideoCall: isVideo,
              isIncoming: true,
              callkitAccepted:
                  true, // CallPage handles call:accept + callkit lifecycle
            ),
          ),
        )
        .then((_) {
          _isShowingIncomingCall = false;
        });
  }

  // ─── Decline ─────────────────────────────────────────────────────────────

  void _onCallkitDecline(Map<String, dynamic> body) {
    final extra = _extra(body);
    final chatId = extra['chatId']?.toString() ?? body['id']?.toString() ?? '';
    final callerId = extra['callerId']?.toString() ?? '';

    debugPrint('📞 Callkit declined — chatId: $chatId');
    _isShowingIncomingCall = false;

    final socket = _ref.read(socketServiceProvider);
    socket.socket?.emit('call:reject', {
      'chatId': chatId,
      'callerId': callerId,
    });
  }

  // ─── Ended ───────────────────────────────────────────────────────────────

  void _onCallkitEndedOrTimeout(Map<String, dynamic> body) {
    final extra = _extra(body);
    final chatId = extra['chatId']?.toString() ?? body['id']?.toString() ?? '';
    debugPrint('📞 Callkit ended — chatId: $chatId');
    _isShowingIncomingCall = false;
  }

  // ─── Timeout (callkit auto-dismissed after duration) ─────────────────────

  void _onCallkitTimeout(Map<String, dynamic> body) {
    final extra = _extra(body);
    final chatId = extra['chatId']?.toString() ?? body['id']?.toString() ?? '';
    final callerId = extra['callerId']?.toString() ?? '';

    debugPrint('📞 Callkit timeout — chatId: $chatId, emitting call:reject');
    _isShowingIncomingCall = false;

    // Notify the server so the caller sees "no answer"
    final socket = _ref.read(socketServiceProvider);
    socket.socket?.emit('call:reject', {
      'chatId': chatId,
      'callerId': callerId,
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
    try {
      // Small delay so the main event loop is fully running and the onEvent
      // stream has a chance to deliver actionCallAccept first.
      await Future.delayed(const Duration(milliseconds: 800));

      if (_isShowingIncomingCall) return; // already handled by onEvent

      final dynamic result = await FlutterCallkitIncoming.activeCalls();
      if (result == null) return;

      // activeCalls() returns a List on Android
      final List<dynamic> calls = result is List ? result : [result];
      if (calls.isEmpty) return;

      // Give the onEvent stream one more second to deliver actionCallAccept.
      // If the user truly tapped Accept on callkit, that event fires within
      // a few hundred ms — well before this second delay.
      await Future.delayed(const Duration(seconds: 1));
      if (_isShowingIncomingCall) return;

      // Active calls found but no actionCallAccept event arrived.
      // These are stale callkit entries left over from a previous app session
      // (e.g. the app was force-closed while a call was active).
      // Clear them so they don't re-open on every subsequent app launch.
      debugPrint(
        '📞 Clearing ${calls.length} stale callkit call(s) from previous session',
      );
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('📞 _checkKilledStateCall error: $e');
    }
  }

  // ─── Socket handlers (foreground) ────────────────────────────────────────

  void _registerSocketCallHandlers() {
    final socketService = _ref.read(socketServiceProvider);

    // ─── Caller cancelled before we answered ─────────────────────────────
    socketService.on('call:cancelled', (data) {
      if (data is! Map<String, dynamic>) return;
      final chatId = data['chatId']?.toString() ?? '';
      debugPrint('📞 call:cancelled received — chatId: $chatId');

      // Dismiss any native callkit UI
      if (chatId.isNotEmpty) FlutterCallkitIncoming.endCall(chatId);
      _isShowingIncomingCall = false;
      _ref.read(incomingCallProvider.notifier).setCall(null);

      // Pop IncomingCallScreen if it is on top
      final nav = navigatorKey.currentState;
      if (nav != null && nav.canPop()) nav.pop();
    });

    // ─── Receiver is busy on another call ────────────────────────────────
    socketService.on('call:busy', (data) {
      if (data is! Map<String, dynamic>) return;
      final chatId = data['chatId']?.toString() ?? '';
      debugPrint('📞 call:busy received — chatId: $chatId');

      // Dismiss callkit if showing (shouldn't normally be visible for the
      // caller, but end it just in case)
      if (chatId.isNotEmpty) FlutterCallkitIncoming.endCall(chatId);

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

      navigatorKey.currentState
          ?.push(
            ScaleFadePageRoute(
              builder: (_) => IncomingCallScreen(
                callId: 'call_$chatId',
                chatId: chatId,
                callerId: callerId,
                callerName: callerName,
                callerAvatar: callerAvatar,
                isVideo: type == 'video',
              ),
            ),
          )
          .then((_) {
            _isShowingIncomingCall = false;
            _ref.read(incomingCallProvider.notifier).setCall(null);
            // Hide any stale callkit banner for this call
            FlutterCallkitIncoming.endCall(chatId);
          });
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Safely extract the 'extra' map from a callkit body.
  Map<String, dynamic> _extra(Map<String, dynamic> body) {
    final raw = body['extra'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

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
    _callkitSub?.cancel();
  }
}
