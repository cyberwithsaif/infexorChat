package com.infexor.infexor_chat

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Rational
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.infexor.infexor_chat/calls"
    private val ONGOING_CHANNEL_ID = "ONGOING_CALL_CHANNEL"
    private val ONGOING_NOTIFICATION_ID = 201
    private var methodChannel: MethodChannel? = null
    private var isInVideoCall = false

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
            } else if (call.method == "enterPiP") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val params = PictureInPictureParams.Builder()
                        .setAspectRatio(Rational(9, 16))
                        .build()
                    enterPictureInPictureMode(params)
                    result.success(true)
                } else {
                    result.success(false)
                }
            } else if (call.method == "setInVideoCall") {
                isInVideoCall = call.argument<Boolean>("value") ?: false
                result.success(null)
            } else if (call.method == "showOngoingCallNotification") {
                val callerName = call.argument<String>("callerName") ?: "Unknown"
                val isVideo = call.argument<Boolean>("isVideo") ?: false
                showOngoingCallNotification(callerName, isVideo)
                result.success(null)
            } else if (call.method == "hideOngoingCallNotification") {
                hideOngoingCallNotification()
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
        val action = intent.getStringExtra("callAction") ?: return

        // "resume" is from the ongoing call notification tap — just bring app to
        // foreground and tell Flutter. No need to cache as pending.
        if (action == "resume") {
            methodChannel?.invokeMethod("onCallEvent", mapOf(
                "action" to "resume"
            ))
            return
        }

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

    private fun clearPendingCall() {
        pendingCallAction = null
        pendingCallId = null
        pendingCallerId = null
        pendingCallerName = null
        pendingIsVideo = null
        pendingCallerAvatar = null
    }

    // Auto-enter PiP when user presses Home during a video call
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isInVideoCall && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(9, 16))
                .build()
            enterPictureInPictureMode(params)
        }
    }

    // Notify Flutter when PiP mode changes
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod("onPiPChanged", mapOf(
            "isInPiP" to isInPictureInPictureMode
        ))
    }

    // ─── Ongoing call notification ───────────────────────────────────────

    private fun createOngoingCallChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ONGOING_CHANNEL_ID,
                "Ongoing Call",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            channel.setSound(null, null)
            channel.enableVibration(false)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun showOngoingCallNotification(callerName: String, isVideo: Boolean) {
        createOngoingCallChannel()

        val tapIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("callAction", "resume")
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val tapPendingIntent = PendingIntent.getActivity(
            this, 100, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val callType = if (isVideo) "video call" else "call"
        val notification = NotificationCompat.Builder(this, ONGOING_CHANNEL_ID)
            .setContentTitle("Ongoing $callType")
            .setContentText("Tap to return to $callerName")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(tapPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setUsesChronometer(true)
            .setWhen(System.currentTimeMillis())
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(ONGOING_NOTIFICATION_ID, notification)
    }

    private fun hideOngoingCallNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.cancel(ONGOING_NOTIFICATION_ID)
    }
}
