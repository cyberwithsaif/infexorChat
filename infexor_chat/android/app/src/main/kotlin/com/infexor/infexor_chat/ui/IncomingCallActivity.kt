package com.infexor.infexor_chat.ui

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.app.Activity
import com.infexor.infexor_chat.MainActivity
import com.infexor.infexor_chat.service.CallForegroundService

class IncomingCallActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Wake up screen and show over lockscreen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        val action = intent.getStringExtra("action")
        val callerName = intent.getStringExtra("callerName")
        val callId = intent.getStringExtra("callId")
        val callerId = intent.getStringExtra("callerId")
        val isVideo = intent.getStringExtra("isVideo")
        val callerAvatar = intent.getStringExtra("callerAvatar")

        if (action == "accept") {
            // Shut down the ringing service since the user interacted
            stopService(Intent(this, CallForegroundService::class.java))

            // Launch the main Flutter activity and pass the call data
            val mainIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("callAction", "accept")
                putExtra("callerName", callerName)
                putExtra("callId", callId)
                putExtra("callerId", callerId)
                putExtra("isVideo", isVideo)
                putExtra("callerAvatar", callerAvatar)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(mainIntent)
            finish()
            return
        }

        if (action == "reject") {
            // Shut down the ringing service since the user interacted
            stopService(Intent(this, CallForegroundService::class.java))

            // Launch main Flutter activity to tell the server we rejected
            val mainIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("callAction", "reject")
                putExtra("callId", callId)
                putExtra("callerId", callerId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(mainIntent)
            finish()
            return
        }

        // If no action, just wake up the app into ringing state
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("callAction", "ring")
            putExtra("callerName", callerName)
            putExtra("callId", callId)
            putExtra("callerId", callerId)
            putExtra("isVideo", isVideo)
            putExtra("callerAvatar", callerAvatar)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(mainIntent)
        finish()
    }
}
