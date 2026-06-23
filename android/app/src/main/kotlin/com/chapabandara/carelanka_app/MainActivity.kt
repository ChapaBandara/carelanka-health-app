package com.chapabandara.carelanka_app

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Allow this activity to show on the lock screen and wake the display
        // so that full-screen alarm-style notifications work correctly.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        // Dismiss the keyguard (lock screen) when the notification is tapped
        // so the user can immediately interact with the Taken / Snooze / Skip UI.
        try {
            val keyguardManager =
                getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                keyguardManager.requestDismissKeyguard(this, null)
            }
        } catch (_: Exception) {
            // Non-fatal — swallow and continue.
        }
    }
}
