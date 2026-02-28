package com.infexor.infexor_chat.service

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.infexor.infexor_chat.R
import com.infexor.infexor_chat.ui.IncomingCallActivity

class CallForegroundService : Service() {

    private val CHANNEL_ID = "CALL_CHANNEL"
    private val TIMEOUT = 30000L

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

        val callerName = intent?.getStringExtra("callerName")
        val callId = intent?.getStringExtra("callId")
        val callerId = intent?.getStringExtra("callerId")
        val isVideo = intent?.getStringExtra("isVideo")
        val callerAvatar = intent?.getStringExtra("callerAvatar")

        createNotificationChannel()

        val fullScreenIntent = Intent(this, IncomingCallActivity::class.java).apply {
            putExtra("callerName", callerName)
            putExtra("callId", callId)
            putExtra("callerId", callerId)
            putExtra("isVideo", isVideo)
            putExtra("callerAvatar", callerAvatar)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val acceptIntent = Intent(this, IncomingCallActivity::class.java).apply {
            putExtra("action", "accept")
            putExtra("callerName", callerName)
            putExtra("callId", callId)
            putExtra("callerId", callerId)
            putExtra("isVideo", isVideo)
            putExtra("callerAvatar", callerAvatar)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val acceptPendingIntent = PendingIntent.getActivity(
            this, 1, acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val rejectIntent = Intent(this, IncomingCallActivity::class.java).apply {
            putExtra("action", "reject")
            putExtra("callerName", callerName)
            putExtra("callId", callId)
            putExtra("callerId", callerId)
            putExtra("isVideo", isVideo)
            putExtra("callerAvatar", callerAvatar)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val rejectPendingIntent = PendingIntent.getActivity(
            this, 2, rejectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Incoming Call")
            .setContentText("$callerName is calling...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            // Note: Since you're not passing actual drawables yet, we'll use android internal ones
            .addAction(android.R.drawable.ic_menu_call, "Accept", acceptPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Reject", rejectPendingIntent)
            .setOngoing(true)
            .build()

        // Must pass service type on API 29+ to match the manifest foregroundServiceType
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this, 101, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
            )
        } else {
            startForeground(101, notification)
        }

        Handler(Looper.getMainLooper()).postDelayed({
            stopSelf()
        }, TIMEOUT)

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Notifications",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
