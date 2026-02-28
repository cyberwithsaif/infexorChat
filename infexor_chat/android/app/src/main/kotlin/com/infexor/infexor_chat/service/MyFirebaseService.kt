package com.infexor.infexor_chat.service

import android.content.Intent
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val type = remoteMessage.data["type"] ?: return

        // Backend sends type = "audio_call" (audio) or "video_call" (video)
        if (type == "call" || type == "audio_call" || type == "video_call") {
            val intent = Intent(this, CallForegroundService::class.java)
            intent.putExtra("callerName", remoteMessage.data["callerName"])
            // Backend uses chatId as the unique call identifier
            intent.putExtra("callId", remoteMessage.data["chatId"])
            intent.putExtra("callerId", remoteMessage.data["callerId"])
            intent.putExtra("isVideo", (type == "video_call").toString())
            intent.putExtra("callerAvatar", remoteMessage.data["callerAvatar"])
            ContextCompat.startForegroundService(this, intent)
            return
        }

        // Call cancelled or caller is busy — stop the ringing service
        if (type == "call_cancel" || type == "call_busy") {
            stopService(Intent(this, CallForegroundService::class.java))
        }
    }
}
