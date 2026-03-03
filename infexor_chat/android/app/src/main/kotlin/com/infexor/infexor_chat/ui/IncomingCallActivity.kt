package com.infexor.infexor_chat.ui

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import android.app.Activity
import com.infexor.infexor_chat.MainActivity
import com.infexor.infexor_chat.R
import com.infexor.infexor_chat.service.CallForegroundService

class IncomingCallActivity : Activity() {

    private var pulseAnimator: AnimatorSet? = null

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

        // Keep screen on while this activity is showing
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val action = intent.getStringExtra("action")
        val callerName = intent.getStringExtra("callerName") ?: "Unknown"
        val callId = intent.getStringExtra("callId")
        val callerId = intent.getStringExtra("callerId")
        val isVideo = intent.getStringExtra("isVideo") ?: "false"
        val callerAvatar = intent.getStringExtra("callerAvatar")
        val isVideoCall = isVideo == "true"

        // If action is accept or reject (from notification buttons), handle immediately
        if (action == "accept") {
            stopService(Intent(this, CallForegroundService::class.java))
            launchMainActivity("accept", callerName, callId, callerId, isVideo, callerAvatar)
            return
        }
        if (action == "reject") {
            stopService(Intent(this, CallForegroundService::class.java))
            launchMainActivity("reject", callerName, callId, callerId, isVideo, callerAvatar)
            return
        }

        // Show full-screen incoming call UI
        setContentView(R.layout.activity_incoming_call)

        // Set caller info
        val tvCallerName = findViewById<TextView>(R.id.tvCallerName)
        val tvCallType = findViewById<TextView>(R.id.tvCallType)
        val tvSubtitle = findViewById<TextView>(R.id.tvSubtitle)
        val tvAvatarInitial = findViewById<TextView>(R.id.tvAvatarInitial)
        val btnAccept = findViewById<FrameLayout>(R.id.btnAccept)
        val btnDecline = findViewById<FrameLayout>(R.id.btnDecline)

        tvCallerName.text = callerName
        tvCallType.text = if (isVideoCall) "Incoming Video Call" else "Incoming Voice Call"
        tvSubtitle.text = if (isVideoCall) "Infexor Video Call" else "Infexor Voice Call"

        // Set avatar initial
        val initial = if (callerName.isNotEmpty()) callerName[0].uppercase() else "?"
        tvAvatarInitial.text = initial

        // Start pulse animation on rings
        startPulseAnimation()

        // Accept button
        btnAccept.setOnClickListener {
            pulseAnimator?.cancel()
            stopService(Intent(this, CallForegroundService::class.java))
            launchMainActivity("accept", callerName, callId, callerId, isVideo, callerAvatar)
        }

        // Decline button
        btnDecline.setOnClickListener {
            pulseAnimator?.cancel()
            stopService(Intent(this, CallForegroundService::class.java))
            launchMainActivity("reject", callerName, callId, callerId, isVideo, callerAvatar)
        }
    }

    private fun startPulseAnimation() {
        val ring1 = findViewById<View>(R.id.pulseRing1)
        val ring2 = findViewById<View>(R.id.pulseRing2)

        val scaleX1 = ObjectAnimator.ofFloat(ring1, "scaleX", 1.0f, 1.6f).apply {
            duration = 1500; repeatCount = ObjectAnimator.INFINITE; repeatMode = ObjectAnimator.RESTART
        }
        val scaleY1 = ObjectAnimator.ofFloat(ring1, "scaleY", 1.0f, 1.6f).apply {
            duration = 1500; repeatCount = ObjectAnimator.INFINITE; repeatMode = ObjectAnimator.RESTART
        }
        val alpha1 = ObjectAnimator.ofFloat(ring1, "alpha", 0.8f, 0.0f).apply {
            duration = 1500; repeatCount = ObjectAnimator.INFINITE; repeatMode = ObjectAnimator.RESTART
        }

        val scaleX2 = ObjectAnimator.ofFloat(ring2, "scaleX", 1.0f, 1.6f).apply {
            duration = 1500; repeatCount = ObjectAnimator.INFINITE; repeatMode = ObjectAnimator.RESTART; startDelay = 750
        }
        val scaleY2 = ObjectAnimator.ofFloat(ring2, "scaleY", 1.0f, 1.6f).apply {
            duration = 1500; repeatCount = ObjectAnimator.INFINITE; repeatMode = ObjectAnimator.RESTART; startDelay = 750
        }
        val alpha2 = ObjectAnimator.ofFloat(ring2, "alpha", 0.8f, 0.0f).apply {
            duration = 1500; repeatCount = ObjectAnimator.INFINITE; repeatMode = ObjectAnimator.RESTART; startDelay = 750
        }

        pulseAnimator = AnimatorSet().apply {
            playTogether(scaleX1, scaleY1, alpha1, scaleX2, scaleY2, alpha2)
            start()
        }
    }

    private fun launchMainActivity(
        callAction: String,
        callerName: String?,
        callId: String?,
        callerId: String?,
        isVideo: String?,
        callerAvatar: String?
    ) {
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("callAction", callAction)
            putExtra("callerName", callerName)
            putExtra("callId", callId)
            putExtra("callerId", callerId)
            putExtra("isVideo", isVideo)
            putExtra("callerAvatar", callerAvatar)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(mainIntent)
        finish()
    }

    override fun onDestroy() {
        pulseAnimator?.cancel()
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // Do nothing — user must accept or decline
    }
}
