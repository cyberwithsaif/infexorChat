import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/routes.dart';
import '../utils/animated_page_route.dart';
import '../../features/chat/screens/incoming_call_screen.dart';
import '../../features/chat/services/socket_service.dart';
import 'webrtc_service.dart';

final callManagerProvider = Provider<CallManager>((ref) {
  return CallManager(ref);
});

class CallManager {
  final Ref _ref;
  bool _initialized = false;
  bool _isShowingIncomingCall = false; // Prevent duplicate screens

  CallManager(this._ref);

  void init() {
    if (_initialized) return;
    _initialized = true;

    final socketService = _ref.read(socketServiceProvider);

    socketService.on('call:incoming', (data) async {
      if (data is Map<String, dynamic>) {
        // Prevent duplicate incoming call screens
        if (_isShowingIncomingCall) {
          debugPrint('📞 Ignoring duplicate call:incoming event');
          return;
        }

        final chatId = data['chatId']?.toString() ?? '';
        final callerId = data['callerId']?.toString() ?? '';
        final type = data['type']?.toString() ?? 'audio';

        // ─── BUSY CHECK: Auto-decline if already on an active call ───
        final webrtc = WebRTCService();
        if (webrtc.isCallActive) {
          debugPrint('📞 User is busy on another call — sending busy signal');
          socketService.socket?.emit('call:busy', {
            'chatId': chatId,
            'callerId': callerId,
          });
          return;
        }

        // Extract caller info from the server data
        String callerName = 'Unknown';
        String? callerAvatar;

        // Server may send caller info directly in the event data
        final callerData = data['caller'] ?? data['callerInfo'];
        if (callerData is Map) {
          callerName = callerData['name']?.toString() ?? 'Unknown';
          callerAvatar = callerData['avatar']?.toString();
        }

        // If still unknown, try to look up name from data fields
        if (callerName == 'Unknown') {
          callerName = data['callerName']?.toString() ?? 'Unknown';
          callerAvatar ??= data['callerAvatar']?.toString();
        }

        // Try device contacts cache as fallback
        if (callerName == 'Unknown' && callerId.isNotEmpty) {
          try {
            if (Hive.isBoxOpen('contacts_cache')) {
              final savedName = Hive.box('contacts_cache').get(callerId);
              if (savedName != null && savedName.toString().isNotEmpty) {
                callerName = savedName.toString();
              }
            }
          } catch (_) {}
        }

        // Try to look up from cached chat participants
        if (callerName == 'Unknown' && callerId.isNotEmpty) {
          try {
            if (Hive.isBoxOpen('user_names_cache')) {
              final cached = Hive.box('user_names_cache').get(callerId);
              if (cached is Map) {
                callerName = cached['name']?.toString() ?? 'Unknown';
                callerAvatar ??= cached['avatar']?.toString();
              }
            }
          } catch (_) {}
        }

        // Fallback: use phone number if available
        if (callerName == 'Unknown') {
          final phone = data['callerPhone']?.toString();
          if (phone != null && phone.isNotEmpty) {
            callerName = phone;
          }
        }

        _isShowingIncomingCall = true;

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
              // Reset flag when screen is popped
              _isShowingIncomingCall = false;
            });
      }
    });
  }
}
