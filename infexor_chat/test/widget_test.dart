import 'package:flutter_test/flutter_test.dart';
import 'package:infexor/main.dart';

/// Unit tests for the FCM payload routing helpers in main.dart.
///
/// These decide whether an incoming FCM should trigger the full-screen call
/// UI, a call-control signal (cancel/busy), or a plain notification — so the
/// "missed call" receipt must never be mistaken for an active incoming call.
void main() {
  group('isCallPayload', () {
    test('treats active call types as calls', () {
      expect(isCallPayload({'type': 'call'}), isTrue);
      expect(isCallPayload({'type': 'audio_call'}), isTrue);
      expect(isCallPayload({'type': 'video_call'}), isTrue);
    });

    test('never treats a missed-call receipt as an active call', () {
      expect(isCallPayload({'type': 'missed_call'}), isFalse);
      expect(
        isCallPayload({'type': 'audio_call', 'status': 'missed'}),
        isFalse,
      );
    });

    test('messages and broadcasts are not calls', () {
      expect(isCallPayload({'type': 'message'}), isFalse);
      expect(isCallPayload({'type': 'broadcast'}), isFalse);
      expect(isCallPayload({}), isFalse);
    });
  });

  group('isCallControlPayload', () {
    test('recognises cancel and busy signals', () {
      expect(isCallControlPayload({'type': 'call_cancel'}), isTrue);
      expect(isCallControlPayload({'type': 'call_busy'}), isTrue);
    });

    test('an active call is not a control signal', () {
      expect(isCallControlPayload({'type': 'video_call'}), isFalse);
      expect(isCallControlPayload({'type': 'message'}), isFalse);
    });
  });
}
