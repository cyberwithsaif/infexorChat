import re

with open(r'E:\Whatapplikeapp\infexor_chat\lib\core\services\call_manager.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove imports
content = content.replace("import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';", "")
content = content.replace("import 'package:flutter_callkit_incoming/entities/entities.dart';", "")

# Add MethodChannel
content = content.replace("const MethodChannel _voipChannel = MethodChannel(", "const MethodChannel _callsChannel = MethodChannel('com.infexor.infexor_chat/calls');\nconst MethodChannel _voipChannel = MethodChannel(")

# Replace init
init_old = """  void init() {
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
  }"""
init_new = """  void init() {
    if (_initialized) return;
    _initialized = true;

    _callsChannel.setMethodCallHandler(_handleNativeCallEvent);
    _checkKilledStateCall();
    _registerSocketCallHandlers();
    if (Platform.isIOS) _setupIOSVoipChannel();
  }"""
content = content.replace(init_old, init_new)

# Replace StreamSubscription
content = content.replace("  StreamSubscription<CallEvent?>? _callkitSub;", "")

# Replace flutter_callkit_incoming endCall commands
content = content.replace("FlutterCallkitIncoming.endCall(chatId)", "_callsChannel.invokeMethod('endCall', {'chatId': chatId})")
content = content.replace("await FlutterCallkitIncoming.endCall(chatId)", "await _callsChannel.invokeMethod('endCall', {'chatId': chatId})")

# Replace checkKilledStateCall
killed_old = """  Future<void> _checkKilledStateCall() async {
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
  }"""
killed_new = """  Future<void> _checkKilledStateCall() async {
    try {
      final pendingRaw = await _callsChannel.invokeMethod('getPendingCall');
      if (pendingRaw is Map) {
        final pending = Map<dynamic, dynamic>.from(pendingRaw);
        final action = pending['action']?.toString();
        if (action == 'accept') {
          _onCallkitAccept(pending);
        } else if (action == 'reject') {
          _onCallkitDecline(pending);
        } else if (action == 'ring') {
          // Do nothing, just bringing app to foreground
        }
      }
    } catch (e) {
      debugPrint('📞 _checkKilledStateCall error: $e');
    }
  }"""
content = content.replace(killed_old, killed_new)

# Replace handleCallkitEvent
event_old = """  void _handleCallkitEvent(CallEvent? event) {
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
  }"""
event_new = """  Future<void> _handleNativeCallEvent(MethodCall call) async {
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
          break;
      }
    }
  }"""
content = content.replace(event_old, event_new)

# Replace accept signature
content = content.replace("void _onCallkitAccept(Map<String, dynamic> body) {", "void _onCallkitAccept(Map<dynamic, dynamic> body) {")
content = content.replace("void _onCallkitDecline(Map<String, dynamic> body) {", "void _onCallkitDecline(Map<dynamic, dynamic> body) {")

# Remove extra logic
extra_old = """    final extra = _extra(body);
    final chatId = extra['chatId']?.toString() ?? body['id']?.toString() ?? '';
    final callerId = extra['callerId']?.toString() ?? '';
    final callerName =
        extra['callerName']?.toString() ??
        body['nameCaller']?.toString() ??
        'Unknown';
    final callerAvatar = extra['callerAvatar']?.toString();
    final isVideo = extra['isVideo'] == 'true';"""
extra_new = """    final chatId = body['callId']?.toString() ?? '';
    final callerId = body['callerId']?.toString() ?? '';
    final callerName = body['callerName']?.toString() ?? 'Unknown';
    final callerAvatar = body['callerAvatar']?.toString();
    final isVideo = body['isVideo']?.toString() == 'true';"""
content = content.replace(extra_old, extra_new)

extra_dec_old = """    final extra = _extra(body);
    final chatId = extra['chatId']?.toString() ?? body['id']?.toString() ?? '';
    final callerId = extra['callerId']?.toString() ?? '';"""
extra_dec_new = """    final chatId = body['callId']?.toString() ?? '';
    final callerId = body['callerId']?.toString() ?? '';"""
content = content.replace(extra_dec_old, extra_dec_new)

with open(r'E:\Whatapplikeapp\infexor_chat\lib\core\services\call_manager.dart', 'w', encoding='utf-8') as f:
    f.write(content)
