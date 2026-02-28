package com.infexor.infexor_chat

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.infexor.infexor_chat/calls"
    private var methodChannel: MethodChannel? = null

    // Cache the most recent call data so Flutter can grab it when ready
    private var pendingCallAction: String? = null
    private var pendingCallId: String? = null
    private var pendingCallerId: String? = null
    private var pendingCallerName: String? = null
    private var pendingIsVideo: String? = null
    private var pendingCallerAvatar: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getPendingCall") {
                if (pendingCallAction != null) {
                    val data = mapOf(
                        "action" to pendingCallAction,
                        "callId" to pendingCallId,
                        "callerId" to pendingCallerId,
                        "callerName" to pendingCallerName,
                        "isVideo" to pendingIsVideo,
                        "callerAvatar" to pendingCallerAvatar
                    )
                    result.success(data)
                    clearPendingCall()
                } else {
                    result.success(null)
                }
            } else if (call.method == "endCall") {
                val serviceIntent = Intent(context, com.infexor.infexor_chat.service.CallForegroundService::class.java)
                context.stopService(serviceIntent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val action = intent.getStringExtra("callAction")
        if (action != null) {
            // Save it in case Flutter hasn't mounted the MethodChannel yet
            pendingCallAction = action
            pendingCallId = intent.getStringExtra("callId")
            pendingCallerId = intent.getStringExtra("callerId")
            pendingCallerName = intent.getStringExtra("callerName")
            pendingIsVideo = intent.getStringExtra("isVideo")
            pendingCallerAvatar = intent.getStringExtra("callerAvatar")

            // But also try to send it immediately if Flutter is already running
            methodChannel?.invokeMethod("onCallEvent", mapOf(
                "action" to pendingCallAction,
                "callId" to pendingCallId,
                "callerId" to pendingCallerId,
                "callerName" to pendingCallerName,
                "isVideo" to pendingIsVideo,
                "callerAvatar" to pendingCallerAvatar
            ))
        }
    }

    private fun clearPendingCall() {
        pendingCallAction = null
        pendingCallId = null
        pendingCallerId = null
        pendingCallerName = null
        pendingIsVideo = null
        pendingCallerAvatar = null
    }
}
