import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/routes.dart';
import '../utils/animated_page_route.dart';
import '../../features/chat/screens/incoming_call_screen.dart';
import '../../features/chat/screens/call_screen.dart';
import '../../features/chat/services/socket_service.dart';
import 'webrtc_service.dart';

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
    //    flutter_callkit_incoming.activeCalls() returns the last shown call.
    //    If the app was launched by a callkit-accept intent, that call will
    //    be here and the onEvent stream may fire before or after init().
    _checkKilledStateCall();

    // 3. Socket handler for foreground incoming calls.
    _registerSocketCallHandlers();
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
    final extra   = _extra(body);
    final chatId  = extra['chatId']?.toString()  ?? body['id']?.toString() ?? '';
    final callerId   = extra['callerId']?.toString()  ?? '';
    final callerName = extra['callerName']?.toString()
        ?? body['nameCaller']?.toString()
        ?? 'Unknown';
    final callerAvatar = extra['callerAvatar']?.toString();
    final isVideo  = extra['isVideo'] == 'true';

    if (chatId.isEmpty) return;

    debugPrint('📞 Callkit accepted — chatId: $chatId');
    _isShowingIncomingCall = true; // block duplicate socket handler

    // Notify the server the call was accepted
    final socket = _ref.read(socketServiceProvider);
    socket.socket?.emit('call:accept', {
      'chatId':   chatId,
      'callerId': callerId,
    });

    // Navigate to the active call screen
    Future.delayed(const Duration(milliseconds: 200), () {
      if (navigatorKey.currentState == null) return;
      navigatorKey.currentState!.push(
        ScaleFadePageRoute(
          builder: (_) => CallPage(
            chatId:      chatId,
            userId:      callerId,
            callerName:  callerName,
            callerAvatar: callerAvatar,
            isVideoCall: isVideo,
            isIncoming:  true,
          ),
        ),
      ).then((_) {
        _isShowingIncomingCall = false;
        // Mark callkit call as connected then end it gracefully
        FlutterCallkitIncoming.setCallConnected(chatId);
      });
    });
  }

  // ─── Decline ─────────────────────────────────────────────────────────────

  void _onCallkitDecline(Map<String, dynamic> body) {
    final extra    = _extra(body);
    final chatId   = extra['chatId']?.toString()  ?? body['id']?.toString() ?? '';
    final callerId = extra['callerId']?.toString() ?? '';

    debugPrint('📞 Callkit declined — chatId: $chatId');
    _isShowingIncomingCall = false;

    final socket = _ref.read(socketServiceProvider);
    socket.socket?.emit('call:reject', {
      'chatId':   chatId,
      'callerId': callerId,
    });
  }

  // ─── Ended ───────────────────────────────────────────────────────────────

  void _onCallkitEndedOrTimeout(Map<String, dynamic> body) {
    final extra   = _extra(body);
    final chatId  = extra['chatId']?.toString() ?? body['id']?.toString() ?? '';
    debugPrint('📞 Callkit ended — chatId: $chatId');
    _isShowingIncomingCall = false;
  }

  // ─── Timeout (callkit auto-dismissed after duration) ─────────────────────

  void _onCallkitTimeout(Map<String, dynamic> body) {
    final extra    = _extra(body);
    final chatId   = extra['chatId']?.toString()  ?? body['id']?.toString() ?? '';
    final callerId = extra['callerId']?.toString() ?? '';

    debugPrint('📞 Callkit timeout — chatId: $chatId, emitting call:reject');
    _isShowingIncomingCall = false;

    // Notify the server so the caller sees "no answer"
    final socket = _ref.read(socketServiceProvider);
    socket.socket?.emit('call:reject', {
      'chatId':   chatId,
      'callerId': callerId,
    });
  }

  // ─── Killed-state recovery ───────────────────────────────────────────────
  //
  // When the app is killed and the user taps Accept on the callkit UI,
  // Android launches the Flutter engine.  The onEvent stream should deliver
  // Event.actionCallAccept once the engine is running, but we keep a fallback
  // via activeCalls() in case the event is missed due to timing.

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

      final callData = Map<String, dynamic>.from(calls.first as Map);
      final extra    = _extra(callData);
      final chatId   = extra['chatId']?.toString()
          ?? callData['id']?.toString()
          ?? '';
      if (chatId.isEmpty) return;

      // Wait one more second for the onEvent stream — if it fires first,
      // _isShowingIncomingCall will be true and we skip the fallback.
      await Future.delayed(const Duration(seconds: 1));
      if (_isShowingIncomingCall) return;

      debugPrint('📞 Fallback: accepting call from activeCalls() — $chatId');
      _onCallkitAccept(callData);
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

      final chatId   = data['chatId']?.toString()  ?? '';
      final callerId = data['callerId']?.toString() ?? '';
      final type     = data['type']?.toString()     ?? 'audio';

      // Busy check — auto-decline if already on a call
      if (WebRTCService().isCallActive) {
        debugPrint('📞 Busy — rejecting call');
        socketService.socket?.emit('call:busy', {
          'chatId':   chatId,
          'callerId': callerId,
        });
        return;
      }

      final callerName   = _resolveCallerName(data, callerId);
      final callerAvatar = _resolveCallerAvatar(data);

      _isShowingIncomingCall = true;

      navigatorKey.currentState
          ?.push(
            ScaleFadePageRoute(
              builder: (_) => IncomingCallScreen(
                callId:      'call_$chatId',
                chatId:      chatId,
                callerId:    callerId,
                callerName:  callerName,
                callerAvatar: callerAvatar,
                isVideo:     type == 'video',
              ),
            ),
          )
          .then((_) {
            _isShowingIncomingCall = false;
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
