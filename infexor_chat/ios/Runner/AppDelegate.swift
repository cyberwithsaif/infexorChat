import Flutter
import UIKit
import PushKit
import CallKit
import AVFoundation

// ─────────────────────────────────────────────────────────────────────────────
// AppDelegate
//
// Responsibilities:
//   1. Register PushKit (VoIP pushes — works even when app is killed)
//   2. Forward VoIP token to Flutter so it can be sent to backend
//   3. On incoming VoIP push → trigger CallKit via flutter_callkit_incoming
//   4. On cancel/busy push → end any showing CallKit call immediately
//   5. Configure audio session for calls (Bluetooth, speaker)
// ─────────────────────────────────────────────────────────────────────────────

@main
@objc class AppDelegate: FlutterAppDelegate {

    // MARK: - Properties

    private var voipRegistry: PKPushRegistry?

    /// Method channel used to communicate VoIP events to Dart.
    /// Name must match the one in call_manager.dart.
    static let voipChannelName = "com.infexor.infexor_chat/voip"
    private var voipChannel: FlutterMethodChannel?

    // MARK: - Application Lifecycle

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Must be first — registers all Flutter plugins
        GeneratedPluginRegistrant.register(with: self)

        // Set up the method channel after plugins are registered so that
        // the FlutterViewController is fully initialised.
        setupVoipMethodChannel()

        // Configure audio session once at startup
        configureAudioSession()

        // Register for VoIP pushes via PushKit
        setupVoIPPushRegistry()

        // Request regular (non-VoIP) notification permission for chat messages
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Method Channel Setup

    private func setupVoipMethodChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else { return }
        voipChannel = FlutterMethodChannel(
            name: AppDelegate.voipChannelName,
            binaryMessenger: controller.binaryMessenger
        )
        voipChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleVoipMethodCall(call, result: result)
        }
    }

    /// Handles calls FROM Flutter → native.
    private func handleVoipMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "endCall":
            // Flutter asks us to dismiss a CallKit call (e.g. cancel or busy received via socket)
            guard let args = call.arguments as? [String: Any],
                  let callId = args["callId"] as? String else {
                result(nil)
                return
            }
            endCallkitCall(uuid: callId)
            result(nil)

        case "getVoipToken":
            result(UserDefaults.standard.string(forKey: "voip_push_token"))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - PushKit Registration

    private func setupVoIPPushRegistry() {
        voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Regular APNs Token (chat message notifications)

    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Forward to Firebase for regular FCM-over-APNs message notifications
        // (firebase_messaging plugin handles this automatically when registered)
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playAndRecord allows both speaker and earpiece routing
            // .allowBluetooth enables AirPods / BT headsets
            // .allowBluetoothA2DP enables stereo BT output
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            NSLog("⚠️ Failed to configure AVAudioSession: \(error)")
        }
    }

    // MARK: - CallKit Helpers

    /// Ends a CallKit call by UUID string.
    /// Used for call_cancel and call_busy VoIP pushes.
    private func endCallkitCall(uuid: String) {
        guard let flutterPlugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else { return }
        flutterPlugin.endCall(uuid)
    }

    /// When we receive a cancel/busy push, Apple MANDATES that we either:
    ///   a) Report a new call AND immediately end it, OR
    ///   b) Call the fulfillment block without reporting a call (iOS 15.4+).
    ///
    /// We use approach (a) for broadest compatibility.
    private func reportAndEndDummyCall(completion: @escaping () -> Void) {
        let uuid = UUID()
        let config = CXProviderConfiguration()
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        let provider = CXProvider(configuration: config)

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "InfexorChat")
        update.hasVideo = false

        provider.reportNewIncomingCall(with: uuid, update: update) { _ in
            provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
            completion()
        }
    }
}

// MARK: - PKPushRegistryDelegate

extension AppDelegate: PKPushRegistryDelegate {

    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        guard type == .voIP else { return }

        // Convert token bytes to hex string
        let token = pushCredentials.token
            .map { String(format: "%02.2hhx", $0) }
            .joined()

        NSLog("📱 VoIP token registered: \(token)")

        // Persist locally so Flutter can read it synchronously
        UserDefaults.standard.set(token, forKey: "voip_push_token")

        // Forward to Dart — auth_service will POST it to backend
        DispatchQueue.main.async { [weak self] in
            self?.voipChannel?.invokeMethod("onVoipToken", arguments: ["token": token])
        }
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }

        let dict = payload.dictionaryPayload
        let pushType = dict["type"] as? String ?? ""

        NSLog("📱 VoIP push received — type: \(pushType), payload: \(dict)")

        // ── Call Cancel ────────────────────────────────────────────────────
        // Caller hung up before we answered. End CallKit immediately.
        if pushType == "call_cancel" {
            let chatId = dict["chatId"] as? String
                      ?? dict["call_id"] as? String
                      ?? ""
            if !chatId.isEmpty {
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(chatId)
            }
            // Apple requires a call report even for cancel — report + end
            reportAndEndDummyCall(completion: completion)
            return
        }

        // ── Busy Signal ────────────────────────────────────────────────────
        // Receiver is on another call. Notify Flutter to show snackbar.
        if pushType == "call_busy" {
            DispatchQueue.main.async { [weak self] in
                self?.voipChannel?.invokeMethod("onCallBusy", arguments: dict as? [String: Any])
            }
            reportAndEndDummyCall(completion: completion)
            return
        }

        // ── Timeout ───────────────────────────────────────────────────────
        // Server timed out the call (30s no answer).
        if pushType == "call_timeout" {
            let chatId = dict["chatId"] as? String ?? ""
            if !chatId.isEmpty {
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(chatId)
            }
            reportAndEndDummyCall(completion: completion)
            return
        }

        // ── Incoming Call ─────────────────────────────────────────────────
        // CRITICAL: Apple gives us ~5 seconds to call reportNewIncomingCall.
        // SwiftFlutterCallkitIncomingPlugin.showCallkitIncoming(fromPushKit: true)
        // calls the internal CXProvider.reportNewIncomingCall synchronously.

        let chatId      = dict["chatId"] as? String
                       ?? dict["call_id"] as? String
                       ?? UUID().uuidString
        let callerName  = dict["callerName"] as? String
                       ?? dict["caller_name"] as? String
                       ?? "Unknown"
        let callerAvatar = dict["callerAvatar"] as? String
                        ?? dict["avatar"] as? String
                        ?? ""
        let callerPhone  = dict["callerPhone"] as? String ?? callerName
        let callerId     = dict["callerId"] as? String ?? ""
        let isVideo      = pushType == "video_call"

        let data = flutter_callkit_incoming.Data(
            uuid: chatId,
            nameCaller: callerName,
            handle: callerPhone,
            type: isVideo ? 1 : 0
        )
        data.appName      = "Infexor Chat"
        data.avatar       = callerAvatar.isEmpty ? nil : callerAvatar
        data.duration     = 30000  // 30 second timeout in ms
        data.textAccept   = "Accept"
        data.textDecline  = "Decline"
        data.extra = [
            "chatId":       chatId,
            "callerId":     callerId,
            "callerName":   callerName,
            "callerAvatar": callerAvatar,
            "isVideo":      isVideo ? "true" : "false",
        ]

        // Configure iOS-specific CallKit appearance
        let iosParams = flutter_callkit_incoming.IOSParams()
        iosParams.iconTemplateImageData = nil  // use app icon
        iosParams.audioSessionMode              = "voiceChat"
        iosParams.audioSessionActive            = true
        iosParams.audioSessionPreferredSampleRate     = 44100.0
        iosParams.audioSessionPreferredIOBufferDuration = 0.005
        iosParams.supportsDTMF                  = true
        iosParams.supportsHolding               = false  // WhatsApp-style: no hold
        iosParams.supportsGrouping              = false
        iosParams.supportsUngrouping            = false
        iosParams.configureAudioSession         = true
        data.ios = iosParams

        // Show native CallKit incoming call screen
        // fromPushKit: true → plugin calls reportNewIncomingCall immediately
        //              so we satisfy Apple's timing requirement
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)

        completion()
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didInvalidatePushTokenFor type: PKPushType
    ) {
        guard type == .voIP else { return }
        NSLog("📱 VoIP token invalidated — will re-register on next launch")
        UserDefaults.standard.removeObject(forKey: "voip_push_token")
    }
}
