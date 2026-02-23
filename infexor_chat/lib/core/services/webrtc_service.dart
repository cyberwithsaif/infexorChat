import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// P2P WebRTC Service for audio/video calls.
/// Uses the socket server as a signaling relay (no mediasoup/SFU).
class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  io.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // Call State
  bool isCallActive = false;
  String? currentChatId;
  String? _remoteUserId;

  // ICE candidates that arrive before remote description is set
  final List<RTCIceCandidate> _pendingCandidates = [];

  // STUN/TURN servers for NAT traversal
  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
    ],
  };

  /// Callback fired when remote stream is received
  VoidCallback? onRemoteStream;

  /// Callback fired when call is connected (ICE connected)
  VoidCallback? onConnected;

  Future<void> init(io.Socket socket) async {
    _socket = socket;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// Start an outgoing call (caller side)
  Future<void> startCall(String chatId, String remoteUserId, bool video) async {
    currentChatId = chatId;
    _remoteUserId = remoteUserId;
    isCallActive = true;
    _pendingCandidates.clear();

    await _getUserMedia(video);
    await _createPeerConnection();

    // Add local tracks to peer connection
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // Listen for signaling from remote
    _setupSignalingListeners();

    // Create and send offer
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': video,
    });
    await _peerConnection!.setLocalDescription(offer);

    _socket?.emit('webrtc:offer', {
      'chatId': chatId,
      'targetUserId': remoteUserId,
      'sdp': offer.toMap(),
    });

    debugPrint('📞 WebRTC: Sent offer to $remoteUserId');
  }

  /// Join an incoming call (callee side)
  Future<void> joinCall(String chatId, String remoteUserId, bool video) async {
    currentChatId = chatId;
    _remoteUserId = remoteUserId;
    isCallActive = true;
    _pendingCandidates.clear();

    await _getUserMedia(video);
    await _createPeerConnection();

    // Add local tracks to peer connection
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // Listen for signaling from remote
    _setupSignalingListeners();

    debugPrint('📞 WebRTC: Ready to receive offer from $remoteUserId');
  }

  Future<void> _getUserMedia(bool video) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video
          ? {
              'width': 1280,
              'height': 720,
              'frameRate': 30,
              'facingMode': 'user',
            }
          : false,
    });
    localRenderer.srcObject = _localStream;

    // Force audio to earpiece for voice calls, loudspeaker for video
    if (!video) {
      Helper.setSpeakerphoneOn(false);
    }
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceConfig);

    // When we receive remote tracks
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('📞 WebRTC: onTrack - ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        onRemoteStream?.call();
      }
    };

    // Also handle older onAddStream for compatibility
    _peerConnection!.onAddStream = (MediaStream stream) {
      debugPrint('📞 WebRTC: onAddStream');
      remoteRenderer.srcObject = stream;
      onRemoteStream?.call();
    };

    // Send ICE candidates to remote via socket
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_remoteUserId != null) {
        _socket?.emit('webrtc:ice-candidate', {
          'chatId': currentChatId,
          'targetUserId': _remoteUserId,
          'candidate': candidate.toMap(),
        });
      }
    };

    // Track connection state
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('📞 WebRTC: ICE state = $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        onConnected?.call();
      }
    };
  }

  void _setupSignalingListeners() {
    // Receive SDP offer (callee side)
    _socket?.on('webrtc:offer', (data) async {
      if (data is! Map) return;
      final chatId = data['chatId']?.toString();
      if (chatId != currentChatId) return;

      debugPrint('📞 WebRTC: Received offer');

      final sdp = data['sdp'];
      final offer = RTCSessionDescription(sdp['sdp'], sdp['type']);
      await _peerConnection?.setRemoteDescription(offer);

      // Process any pending ICE candidates
      for (final c in _pendingCandidates) {
        await _peerConnection?.addCandidate(c);
      }
      _pendingCandidates.clear();

      // Create and send answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _socket?.emit('webrtc:answer', {
        'chatId': chatId,
        'targetUserId': _remoteUserId,
        'sdp': answer.toMap(),
      });

      debugPrint('📞 WebRTC: Sent answer');
    });

    // Receive SDP answer (caller side)
    _socket?.on('webrtc:answer', (data) async {
      if (data is! Map) return;
      final chatId = data['chatId']?.toString();
      if (chatId != currentChatId) return;

      debugPrint('📞 WebRTC: Received answer');

      final sdp = data['sdp'];
      final answer = RTCSessionDescription(sdp['sdp'], sdp['type']);
      await _peerConnection?.setRemoteDescription(answer);

      // Process any pending ICE candidates
      for (final c in _pendingCandidates) {
        await _peerConnection?.addCandidate(c);
      }
      _pendingCandidates.clear();
    });

    // Receive ICE candidates
    _socket?.on('webrtc:ice-candidate', (data) async {
      if (data is! Map) return;
      final chatId = data['chatId']?.toString();
      if (chatId != currentChatId) return;

      final candidateMap = data['candidate'];
      if (candidateMap == null) return;

      final candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );

      // If remote description isn't set yet, queue the candidate
      final remoteDesc = await _peerConnection?.getRemoteDescription();
      if (remoteDesc == null) {
        _pendingCandidates.add(candidate);
      } else {
        await _peerConnection?.addCandidate(candidate);
      }
    });
  }

  void endCall() {
    isCallActive = false;

    // Clean up local stream
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream?.dispose();
    _localStream = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    // Close peer connection
    _peerConnection?.close();
    _peerConnection = null;

    // Remove signaling listeners
    _socket?.off('webrtc:offer');
    _socket?.off('webrtc:answer');
    _socket?.off('webrtc:ice-candidate');

    _remoteUserId = null;
    currentChatId = null;
    _pendingCandidates.clear();
    onRemoteStream = null;
    onConnected = null;
  }
}
