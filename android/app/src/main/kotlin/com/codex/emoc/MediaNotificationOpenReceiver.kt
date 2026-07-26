package com.codex.emoc

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

class MediaNotificationOpenReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        val appContext = context.applicationContext
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                // Some Android variants resolve the media notification content
                // intent together with a transport command. Keep that path from
                // foregrounding Flutter while preserving deliberate card taps.
                if (!MediaTransportGate.wasTransportCommandRecent(450L)) {
                    val openIntent = Intent(appContext, MainActivity::class.java)
                        .setAction(SystemMediaController.ACTION_OPEN_PLAYER)
                        .addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                        )
                    appContext.startActivity(openIntent)
                }
            } finally {
                pendingResult.finish()
            }
        }, OPEN_DELAY_MS)
    }

    companion object {
        private const val OPEN_DELAY_MS = 140L
    }
}
