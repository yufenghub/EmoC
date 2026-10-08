package com.codex.emoc

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MediaActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!MainActivity.hasPlaybackSession()) {
            context.startActivity(Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(PlaybackWidget.EXTRA_ACTION, intent.action))
            return
        }
        MediaTransportGate.recordTransportCommand()
        MainActivity.dispatchMediaAction(intent.action.orEmpty())
    }
}
